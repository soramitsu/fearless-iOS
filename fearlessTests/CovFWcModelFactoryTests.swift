import FearlessWalletConnect
import SSFModels
import XCTest
@testable import fearless

final class CovFWcModelFactoryTests: XCTestCase {
    private let factory = WalletConnectModelFactoryImpl()
    private let chains = [covFWcEthereumChain(id: "1"), covFWcEthereumChain(id: "56"), covFMiscChain(id: "substrate")]

    func testRequiredAndApprovedOptionalChainsGetWalletAccountsAndMethods() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let proposal = try covFWcProposal(
            required: ["eip155": ProposalNamespace(chains: [covFWcChain("eip155:1")], methods: ["personal_sign"], events: ["chainChanged"])],
            optional: ["eip155": ProposalNamespace(chains: [covFWcChain("eip155:56")], methods: ["eth_sendTransaction"], events: ["accountsChanged"])]
        )
        let namespaces = try factory.createSessionNamespaces(from: proposal, wallets: [wallet], chains: chains, optionalChainIds: ["56"])
        let namespace = try XCTUnwrap(namespaces["eip155"])
        XCTAssertEqual(Set(namespace.chains ?? []), [try covFWcChain("eip155:1"), try covFWcChain("eip155:56")])
        XCTAssertEqual(Set(namespace.accounts.map(\.blockchain)), [try covFWcChain("eip155:1"), try covFWcChain("eip155:56")])
        XCTAssertEqual(Set(namespace.accounts.map(\.address)).count, 1)
        XCTAssertEqual(namespace.methods, ["personal_sign", "eth_sendTransaction"])
        XCTAssertEqual(namespace.events, ["chainChanged", "accountsChanged"])
    }

    func testOptionalNamespacesAreIgnoredWithoutApprovedOptionalChains() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let proposal = try covFWcProposal(
            required: ["eip155": ProposalNamespace(chains: [covFWcChain("eip155:1")], methods: ["personal_sign"], events: [])],
            optional: ["eip155": ProposalNamespace(chains: [covFWcChain("eip155:56")], methods: ["eth_sendTransaction"], events: [])]
        )
        let namespace = try XCTUnwrap(factory.createSessionNamespaces(from: proposal, wallets: [wallet], chains: chains, optionalChainIds: nil)["eip155"])
        XCTAssertEqual(namespace.chains, [try covFWcChain("eip155:1")])
        XCTAssertEqual(namespace.methods, ["personal_sign"])
        XCTAssertEqual(namespace.accounts.count, 1)
    }

    func testUnknownRequiredChainIsRejected() throws {
        let proposal = try covFWcProposal(
            required: ["eip155": ProposalNamespace(chains: [covFWcChain("eip155:999")], methods: ["personal_sign"], events: [])],
            optional: nil
        )
        XCTAssertThrowsError(
            try factory.createSessionNamespaces(from: proposal, wallets: [AccountGenerator.generateMetaAccount()], chains: chains, optionalChainIds: [])
        ) { XCTAssertEqual($0 as? AutoNamespacesError, .requiredChainsNotSatisfied) }
    }

    func testResolveChainMatchesCaipReferenceOrThrows() throws {
        XCTAssertEqual(try factory.resolveChain(for: covFWcChain("eip155:56"), chains: chains).chainId, "56")
        XCTAssertThrowsError(try factory.resolveChain(for: covFWcChain("eip155:2"), chains: chains)) {
            XCTAssertEqual($0 as? AutoNamespacesError, .requiredChainsNotSatisfied)
        }
        let resolved = factory.resolveChains(for: [try covFWcChain("eip155:1"), try covFWcChain("eip155:7")], chains: chains)
        XCTAssertEqual(resolved.map(\.chainId), ["1"])
    }

    func testParseMethodAcceptsKnownMethodsOnly() throws {
        let blockchain = try covFWcChain("eip155:1")
        for method in WalletConnectMethod.allCases {
            let request = Request(topic: "t", method: method.rawValue, params: AnyCodable([String]()), chainId: blockchain)
            XCTAssertEqual(try factory.parseMethod(from: request), method)
        }
        let unknown = Request(topic: "t", method: "eth_unknown", params: AnyCodable([String]()), chainId: blockchain)
        XCTAssertThrowsError(try factory.parseMethod(from: unknown)) {
            XCTAssertEqual($0 as? AutoNamespacesError, .requiredMethodsNotSatisfied)
        }
    }
}

func covFWcChain(_ value: String) throws -> Blockchain {
    try XCTUnwrap(Blockchain(value))
}

func covFWcEthereumChain(id: String) -> ChainModel {
    ChainModel(
        rank: nil, disabled: false, chainId: id, parentId: nil, paraId: nil, name: "EVM \(id)", assets: [], xcm: nil,
        nodes: [], addressPrefix: 0, icon: nil, options: [.ethereum], iosMinAppVersion: nil, identityChain: nil
    )
}

func covFWcProposal(required: [String: ProposalNamespace], optional: [String: ProposalNamespace]?) throws -> Session.Proposal {
    Session.Proposal(
        id: 1_794_000_000_000_101,
        pairingTopic: "covf-pairing",
        proposer: AppMetadata(name: "CovF", description: "", url: "https://covf.invalid", icons: []),
        requiredNamespaces: required,
        optionalNamespaces: optional,
        sessionProperties: nil,
        expiryDate: Date(timeIntervalSinceNow: 300)
    )
}
