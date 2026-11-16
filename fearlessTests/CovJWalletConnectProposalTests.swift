import XCTest
import UIKit
import SoraFoundation
import FearlessWalletConnect
import SSFModels
@testable import fearless

enum CovJWalletConnectFixture {
    static let locale = Locale(identifier: "en_US")

    static func chain(id: String = "1", name: String = "Ethereum") -> ChainModel {
        ChainModel(rank: 1, disabled: false, chainId: id, parentId: nil, paraId: nil, name: name,
                   xcm: nil, nodes: [], addressPrefix: 42, types: nil, icon: nil, options: [.ethereumBased],
                   externalApi: nil, selectedNode: nil, customNodes: nil, iosMinAppVersion: nil, identityChain: nil)
    }

    static func proposal(required: [String: ProposalNamespace] = [:],
                         optional: [String: ProposalNamespace]? = nil) -> Session.Proposal {
        Session.Proposal(id: 1, pairingTopic: "pairing",
                         proposer: AppMetadata(name: "Example dApp", description: "Test", url: "https://example.invalid/app", icons: []),
                         requiredNamespaces: required, optionalNamespaces: optional, sessionProperties: nil,
                         expiryDate: Date(timeIntervalSince1970: 1_800_000_000))
    }

    static func session(required: [String: ProposalNamespace] = [:],
                        namespaces: [String: SessionNamespace] = [:]) -> Session {
        Session(topic: "session", pairingTopic: "pairing",
                peer: AppMetadata(name: "Example dApp", description: "Test", url: "https://example.invalid/app", icons: []),
                requiredNamespaces: required, optionalNamespaces: nil, namespaces: namespaces,
                sessionProperties: nil, expiryDate: Date(timeIntervalSince1970: 1_800_000_000))
    }

    static func wallets(in model: WalletConnectProposalViewModel) -> [WalletConnectProposalCellModel.WalletViewModel] {
        model.cells.compactMap { cell in
            if case let .wallet(wallet) = cell { return wallet }
            return nil
        }
    }
}

final class CovJWalletConnectResolver: WalletConnectModelFactory {
    var resolutions: [String: ChainModel] = [:]
    var approvedWallets: [MetaAccountModel] = []
    var optionalIds: [String]?
    var namespaces: [String: SessionNamespace] = [:]

    func createSessionNamespaces(from proposal: Session.Proposal, wallets: [MetaAccountModel],
                                 chains: [ChainModel], optionalChainIds: [ChainModel.Id]?) throws -> [String: SessionNamespace] {
        approvedWallets = wallets
        optionalIds = optionalChainIds
        return namespaces
    }

    func resolveChain(for blockchain: Blockchain, chains: [ChainModel]) throws -> ChainModel {
        try XCTUnwrap(resolutions[blockchain.absoluteString])
    }

    func resolveChains(for blockchains: Set<Blockchain>, chains: [ChainModel]) -> [ChainModel] {
        blockchains.sorted { $0.absoluteString < $1.absoluteString }.compactMap { resolutions[$0.absoluteString] }
    }

    func parseMethod(from request: Request) throws -> WalletConnectMethod {
        try XCTUnwrap(WalletConnectMethod(rawValue: request.method))
    }
}

final class CovJWalletConnectProposalTests: XCTestCase {
    func testProposalIncludesRequiredOptionalVerificationAndDefaultWalletSelection() throws {
        let blockchain = try XCTUnwrap(Blockchain("eip155:1"))
        let optionalBlockchain = try XCTUnwrap(Blockchain("eip155:137"))
        let chain = CovJWalletConnectFixture.chain()
        let optionalChain = CovJWalletConnectFixture.chain(id: "137", name: "Polygon")
        let resolver = CovJWalletConnectResolver()
        resolver.resolutions = ["eip155:1": chain, "eip155:137": optionalChain]
        let proposal = CovJWalletConnectFixture.proposal(
            required: ["eip155": ProposalNamespace(chains: [blockchain], methods: ["personal_sign"], events: ["accountsChanged"])],
            optional: ["eip155": ProposalNamespace(chains: [optionalBlockchain], methods: ["eth_sendTransaction"], events: ["chainChanged"])]
        )
        let factory = WalletConnectProposalViewModelFactoryImpl(
            status: .proposal(proposal), verification: .mismatch(origin: "https://actual.invalid"),
            walletConnectModelFactory: resolver
        )
        let wallets = [AccountGenerator.generateMetaAccount(), AccountGenerator.generateMetaAccount()]
        var model = try factory.buildProposalSessionViewModel(proposal: proposal, chains: [chain, optionalChain],
                                                              wallets: wallets, locale: CovJWalletConnectFixture.locale)
        XCTAssertEqual(model.cells.count, 8)
        XCTAssertNil(model.indexPath)
        XCTAssertNil(model.expiryDate)
        XCTAssertEqual(model.selectedWalletIds, [wallets[0].metaId])
        XCTAssertEqual(CovJWalletConnectFixture.wallets(in: model).map(\.walletName), wallets.map(\.name))
        guard case let .dAppInfo(app) = model.cells[0],
              case let .dAppInfo(verification) = model.cells[1],
              case let .requiredNetworks(required) = model.cells[2],
              case let .requiredExpandable(permissions) = model.cells[3],
              case let .optionalNetworks(optional) = model.cells[4],
              case let .optionalExpandable(optionalPermissions) = model.cells[5] else {
            return XCTFail("Expected app, verification, networks, and permissions in presentation order")
        }
        XCTAssertEqual(app.title, "Example dApp")
        XCTAssertEqual(app.subtitle, "actual.invalid")
        XCTAssertEqual(verification.subtitle, WalletConnectVerification.mismatch(origin: "https://actual.invalid").title(for: CovJWalletConnectFixture.locale))
        XCTAssertEqual(required.subtitle, "Ethereum")
        XCTAssertEqual(optional.subtitle, "Polygon")
        XCTAssertEqual(permissions.chain, "Ethereum")
        XCTAssertEqual(permissions.methods, "personal_sign")
        XCTAssertEqual(permissions.events, "accountsChanged")
        XCTAssertFalse(permissions.isExpanded)
        XCTAssertEqual(optionalPermissions.methods, "eth_sendTransaction")
        XCTAssertEqual(optionalPermissions.events, "chainChanged")
    }

    func testProposalOmitsEmptyNamespacesAndRejectsUnsupportedRequiredChain() throws {
        let proposal = CovJWalletConnectFixture.proposal()
        let factory = WalletConnectProposalViewModelFactoryImpl(status: .proposal(proposal), walletConnectModelFactory: CovJWalletConnectResolver())
        var model = try factory.buildProposalSessionViewModel(proposal: proposal, chains: [], wallets: [], locale: CovJWalletConnectFixture.locale)
        XCTAssertEqual(model.cells.count, 1)
        XCTAssertNil(model.selectedWalletIds)
        let blockchain = try XCTUnwrap(Blockchain("eip155:999"))
        let unsupported = CovJWalletConnectFixture.proposal(
            required: ["eip155": ProposalNamespace(chains: [blockchain], methods: [], events: [])]
        )
        XCTAssertThrowsError(try factory.buildProposalSessionViewModel(proposal: unsupported, chains: [], wallets: [], locale: CovJWalletConnectFixture.locale)) {
            XCTAssertEqual($0 as? AutoNamespacesError, .requiredChainsNotSatisfied)
        }
        let optionalOnly = CovJWalletConnectFixture.proposal(
            optional: ["eip155": ProposalNamespace(chains: [blockchain], methods: ["personal_sign"], events: [])]
        )
        let optionalModel = try factory.buildProposalSessionViewModel(proposal: optionalOnly, chains: [], wallets: [], locale: CovJWalletConnectFixture.locale)
        XCTAssertEqual(optionalModel.cells.count, 2)
        guard case let .optionalExpandable(permissions) = optionalModel.cells[1] else { return XCTFail("Optional permission remains inspectable") }
        XCTAssertEqual(permissions.chain, "")
        XCTAssertEqual(permissions.methods, "personal_sign")
    }

    func testTappingSelectableCellsTogglesOnlyTheirState() throws {
        let proposal = CovJWalletConnectFixture.proposal()
        let factory = WalletConnectProposalViewModelFactoryImpl(status: .proposal(proposal), walletConnectModelFactory: CovJWalletConnectResolver())
        let details = WalletConnectProposalCellModel.DetailsViewModel(title: "App", subtitle: "Site", icon: nil)
        let expandable = WalletConnectProposalCellModel.ExpandableViewModel(
            cellTitle: "Permissions", chain: "Ethereum", methods: "personal_sign", events: "", isExpanded: false
        )
        let cells: [WalletConnectProposalCellModel] = [
            .dAppInfo(details), .requiredNetworks(details), .optionalNetworks(details),
            .requiredExpandable(expandable), .optionalExpandable(expandable),
            .wallet(.init(metaId: "wallet", walletName: "Savings", isSelected: true))
        ]
        for row in [0, 1, 2, 6] {
            XCTAssertNil(factory.didTapOn(IndexPath(row: row, section: 0), cells: cells))
        }
        for row in [3, 4] {
            let indexPath = IndexPath(row: row, section: 0)
            let updated = try XCTUnwrap(factory.didTapOn(indexPath, cells: cells))
            XCTAssertEqual(updated.indexPath, indexPath)
            XCTAssertEqual(updated.cells.count, cells.count)
            switch updated.cells[row] {
            case let .requiredExpandable(value), let .optionalExpandable(value):
                XCTAssertTrue(value.isExpanded)
                XCTAssertEqual(value.methods, expandable.methods)
                XCTAssertEqual(value.cellTitle, expandable.cellTitle)
            default: XCTFail("Expected expanded permissions")
            }
        }
        var updated = try XCTUnwrap(factory.didTapOn(IndexPath(row: 5, section: 0), cells: cells))
        XCTAssertNil(updated.selectedWalletIds)
        XCTAssertEqual(CovJWalletConnectFixture.wallets(in: updated).first?.walletName, "Savings")
        updated = try XCTUnwrap(factory.didTapOn(IndexPath(row: 5, section: 0), cells: updated.cells))
        XCTAssertEqual(updated.selectedWalletIds, ["wallet"])
        let activeFactory = WalletConnectProposalViewModelFactoryImpl(
            status: .active(CovJWalletConnectFixture.session()), walletConnectModelFactory: CovJWalletConnectResolver()
        )
        XCTAssertNil(activeFactory.didTapOn(IndexPath(row: 5, section: 0), cells: cells))
    }

    func testActiveSessionFindsOnlyApprovedWalletAndFormatsExpiry() throws {
        let chain = CovJWalletConnectFixture.chain()
        let wallet = AccountGenerator.generateMetaAccount()
        let other = AccountGenerator.generateMetaAccount()
        let blockchain = try XCTUnwrap(Blockchain("eip155:1"))
        let address = try XCTUnwrap(wallet.fetch(for: chain.accountRequest())?.toAddress())
        let account = try XCTUnwrap(Account(blockchain: blockchain, address: address))
        let required = ["eip155": ProposalNamespace(chains: [blockchain], methods: ["personal_sign"], events: [])]
        let session = CovJWalletConnectFixture.session(
            required: required,
            namespaces: ["eip155": SessionNamespace(chains: [blockchain], accounts: [account], methods: ["personal_sign"], events: ["accountsChanged"])]
        )
        let resolver = CovJWalletConnectResolver()
        resolver.resolutions = ["eip155:1": chain]
        let factory = WalletConnectProposalViewModelFactoryImpl(status: .active(session), walletConnectModelFactory: resolver)
        var model = try factory.buildActiveSessionViewModel(session: session, chains: [chain], wallets: [other, wallet], locale: CovJWalletConnectFixture.locale)
        XCTAssertEqual(model.cells.count, 3)
        XCTAssertEqual(model.selectedWalletIds, [wallet.metaId])
        XCTAssertEqual(CovJWalletConnectFixture.wallets(in: model).map(\.walletName), [wallet.name])
        XCTAssertEqual(model.expiryDate, DateFormatter.connectionExpiry.value(for: CovJWalletConnectFixture.locale).string(from: session.expiryDate))
        guard case let .dAppInfo(app) = model.cells[0], case let .requiredExpandable(permissions) = model.cells[1] else {
            return XCTFail("Expected active session details")
        }
        XCTAssertEqual(app.subtitle, "example.invalid")
        XCTAssertEqual(permissions.chain, "Ethereum")
        XCTAssertEqual(permissions.methods, "personal_sign")
        XCTAssertEqual(permissions.events, "accountsChanged")
        XCTAssertNotNil(WalletConnectProposalPresenter.SessionStatus.active(session).session)
        XCTAssertNil(WalletConnectProposalPresenter.SessionStatus.active(session).proposal)
        let proposal = CovJWalletConnectFixture.proposal()
        XCTAssertNotNil(WalletConnectProposalPresenter.SessionStatus.proposal(proposal).proposal)
        XCTAssertNil(WalletConnectProposalPresenter.SessionStatus.proposal(proposal).session)
    }

    func testOptionalCellInitializersDiscardMissingModels() {
        XCTAssertNil(WalletConnectProposalCellModel(requiredNetworksViewModel: nil))
        XCTAssertNil(WalletConnectProposalCellModel(requiredExpandableViewModel: nil))
        XCTAssertNil(WalletConnectProposalCellModel(optionalNetworksCaseViewModel: nil))
        XCTAssertNil(WalletConnectProposalCellModel(optionalNetworkExpadableViewModel: nil))
    }
}
