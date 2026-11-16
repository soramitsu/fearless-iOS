import RobinHood
import SoraFoundation
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

enum CovHTxHistoryFixture {
    static func asset(_ id: String, symbol: String, currencyId: String? = nil, utility: Bool = false) -> AssetModel {
        AssetModel(
            id: id,
            name: symbol,
            symbol: symbol,
            precision: 12,
            currencyId: currencyId,
            isUtility: utility,
            isNative: utility
        )
    }

    static let main = asset("cov-main", symbol: "MAIN", currencyId: "0xmain", utility: true)
    static let other = asset("cov-other", symbol: "OTHR", currencyId: "0xother")

    static func chain(
        id: String = "cov-h-history-chain",
        name: String = "Cov history",
        history: String? = "giantsquid",
        options: [ChainOptions]? = nil,
        icon: URL? = URL(string: "https://icons.invalid/chain.svg")
    ) -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: id,
            paraId: nil,
            name: name,
            assets: [main, other],
            xcm: nil,
            nodes: [],
            addressPrefix: 42,
            icon: icon,
            options: options,
            externalApi: ChainModel.ExternalApiSet(
                history: history.flatMap { ChainModel.BlockExplorer(type: $0, url: URL(string: "https://history.invalid")!) }
            ),
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    static func transaction(
        _ id: String,
        type: String,
        status: AssetTransactionStatus = .commited,
        assetId: String = main.id,
        peerId: String = "peer-id",
        firstName: String? = nil,
        lastName: String? = nil,
        peerName: String? = "peer",
        details: String = "",
        amount: Decimal = 1,
        fees: [AssetTransactionFee] = [],
        timestamp: Int64 = 1_700_000_000,
        context: [String: String]? = nil
    ) -> AssetTransactionData {
        AssetTransactionData(
            transactionId: id,
            status: status,
            assetId: assetId,
            peerId: peerId,
            peerFirstName: firstName,
            peerLastName: lastName,
            peerName: peerName,
            details: details,
            amount: AmountDecimal(value: amount),
            fees: fees,
            timestamp: timestamp,
            type: type,
            reason: "",
            context: context
        )
    }

    static func cell(_ id: String, status: AssetTransactionStatus = .commited, icon: UIImage? = nil) -> WalletTransactionHistoryCellViewModel {
        WalletTransactionHistoryCellViewModel(
            transaction: transaction(id, type: TransactionType.outgoing.rawValue, status: status),
            address: "peer-\(id)",
            icon: icon,
            transactionType: "Transfer",
            amountString: "-1 MAIN",
            timeString: "12:00",
            statusIcon: nil,
            status: status,
            incoming: false,
            imageViewModel: RemoteImageViewModel(url: URL(string: "https://icons.invalid/\(id).png")!)
        )
    }

    static func spin(timeout: TimeInterval = 3, until predicate: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }
}

final class CovHTxHistoryFactoryTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")

    private func factory(includesFee: Bool = true, extrinsicIcon: UIImage? = nil) -> WalletTransactionHistoryViewModelFactory {
        let extrinsic = WalletTransactionType(
            backendName: "EXTRINSIC",
            displayName: LocalizableResource { _ in "Extrinsic" },
            isIncome: false,
            typeIcon: extrinsicIcon
        )
        return WalletTransactionHistoryViewModelFactory(
            balanceFormatterFactory: AssetBalanceFormatterFactory(),
            includesFeeInAmount: includesFee,
            transactionTypes: [.incoming, .outgoing, extrinsic],
            chainAsset: ChainAsset(chain: CovHTxHistoryFixture.chain(), asset: CovHTxHistoryFixture.main),
            iconGenerator: UniversalIconGenerator()
        )
    }

    private func items(_ data: [AssetTransactionData], factory: WalletTransactionHistoryViewModelFactory? = nil) throws -> [WalletTransactionHistoryCellViewModel] {
        var sections: [WalletTransactionHistorySection] = []
        _ = try (factory ?? self.factory()).merge(newItems: data, into: &sections, locale: locale)
        return sections.flatMap(\.items)
    }

    func testTransfersCarrySignNamesFeesAndFailureIcon() throws {
        let fee = AssetTransactionFee(identifier: "fee", assetId: CovHTxHistoryFixture.main.id, amount: AmountDecimal(value: 0.5), context: nil)
        let foreignFee = AssetTransactionFee(identifier: "fee2", assetId: "other", amount: AmountDecimal(value: 7), context: nil)
        let rows = try items([
            CovHTxHistoryFixture.transaction(
                "out", type: TransactionType.outgoing.rawValue, status: .rejected, firstName: "Ada", lastName: "Lovelace", fees: [fee, foreignFee]
            ),
            CovHTxHistoryFixture.transaction("in", type: TransactionType.incoming.rawValue, peerName: "sender", fees: [fee])
        ])

        XCTAssertEqual(rows.count, 2)
        let outgoing = rows[0]
        XCTAssertTrue(outgoing.amountString.hasPrefix("-"), outgoing.amountString)
        XCTAssertTrue(outgoing.amountString.contains("1.5"), "The fee of the same asset is added: \(outgoing.amountString)")
        // Names go through `L10n.Common.fullName`; its "common.full_name" key has no strings entry (reported as a bug).
        XCTAssertEqual(outgoing.address, L10n.Common.fullName("Ada", "Lovelace"))
        XCTAssertNotEqual(outgoing.address, "peer", "First/last names take precedence over the peer name")
        XCTAssertFalse(outgoing.incoming)
        XCTAssertNotNil(outgoing.statusIcon)

        let incoming = rows[1]
        XCTAssertTrue(incoming.amountString.hasPrefix("+"), incoming.amountString)
        XCTAssertFalse(incoming.amountString.contains("1.5"), "Incoming amounts never include a fee: \(incoming.amountString)")
        XCTAssertEqual(incoming.address, "sender")
        XCTAssertTrue(incoming.incoming)
        XCTAssertNil(incoming.statusIcon)

        let unknownType = try items(
            [CovHTxHistoryFixture.transaction("plain", type: TransactionType.outgoing.rawValue, peerName: nil)],
            factory: WalletTransactionHistoryViewModelFactory(
                balanceFormatterFactory: AssetBalanceFormatterFactory(),
                includesFeeInAmount: true,
                transactionTypes: [],
                chainAsset: ChainAsset(chain: CovHTxHistoryFixture.chain(), asset: CovHTxHistoryFixture.main),
                iconGenerator: UniversalIconGenerator()
            )
        )
        XCTAssertEqual(unknownType.first?.address, "")
        XCTAssertEqual(unknownType.first?.incoming, false)
    }

    func testRewardsAndSlashesAreStakingRows() throws {
        let languages = locale.rLanguages
        let rows = try items([
            CovHTxHistoryFixture.transaction("reward", type: TransactionType.reward.rawValue),
            CovHTxHistoryFixture.transaction("slash", type: TransactionType.slash.rawValue, status: .pending)
        ])
        XCTAssertEqual(rows.map(\.address), [
            R.string.localizable.stakingReward(preferredLanguages: languages),
            R.string.localizable.stakingSlash(preferredLanguages: languages)
        ])
        XCTAssertEqual(Set(rows.map(\.transactionType)), [R.string.localizable.commonStaking(preferredLanguages: languages)])
        XCTAssertTrue(rows.allSatisfy { $0.amountString.hasPrefix("+") && $0.incoming && $0.icon != nil })
        XCTAssertEqual(rows.map(\.status), [.commited, .pending])
    }

    func testExtrinsicsNameTheirModuleAndCallAndFlagFeeCalls() throws {
        let icon = UIImage()
        let rows = try items(
            [
                CovHTxHistoryFixture.transaction("staking", type: TransactionType.extrinsic.rawValue, firstName: "staking", lastName: "bond"),
                CovHTxHistoryFixture.transaction("fee", type: TransactionType.extrinsic.rawValue, firstName: "balances", lastName: "transfer")
            ],
            factory: factory(extrinsicIcon: icon)
        )
        XCTAssertEqual(rows.map(\.address), ["Staking", "Balances"])
        XCTAssertEqual(rows.map(\.transactionType), ["Bond", "Transfer fee"])
        XCTAssertNotNil(rows[0].icon)
        XCTAssertNil(rows[1].icon)
        XCTAssertTrue(rows.allSatisfy { $0.statusIcon === icon })
        XCTAssertTrue(rows.allSatisfy { $0.imageViewModel != nil })
        XCTAssertTrue(rows.allSatisfy { $0.amountString.hasPrefix("-") })
    }

    func testSwapsJoinSentAndReceivedAmountsAndNameTheirStatus() throws {
        let languages = locale.rLanguages
        let rows = try items([
            CovHTxHistoryFixture.transaction(
                "done", type: TransactionType.swap.rawValue, assetId: "0xother", peerId: "0xmain", details: "2", amount: 3
            ),
            CovHTxHistoryFixture.transaction(
                "waiting", type: TransactionType.swap.rawValue, status: .pending, assetId: "0xunknown", peerId: "0xunknown", details: "x"
            ),
            CovHTxHistoryFixture.transaction("failed", type: TransactionType.swap.rawValue, status: .rejected)
        ])

        XCTAssertEqual(rows.count, 3)
        XCTAssertTrue(rows[0].amountString.contains("-"))
        XCTAssertTrue(rows[0].amountString.contains("2"), rows[0].amountString)
        XCTAssertTrue(rows[0].amountString.contains("3"), rows[0].amountString)
        XCTAssertEqual(rows[0].transactionType, R.string.localizable.polkaswapConfirmationSwappedStub(preferredLanguages: languages))
        XCTAssertEqual(rows[1].transactionType, AssetTransactionStatus.pending.rawValue)
        XCTAssertEqual(rows[2].transactionType, AssetTransactionStatus.rejected.rawValue)
        XCTAssertNotNil(rows[2].statusIcon)
        XCTAssertNil(rows[0].statusIcon)
        XCTAssertTrue(rows.allSatisfy { $0.address == R.string.localizable.polkaswapConfirmationSwapStub(preferredLanguages: languages) })
        XCTAssertTrue(rows.allSatisfy { $0.incoming && $0.imageViewModel != nil })
    }

    func testMergeGroupsByDayReportsChangesAndSkipsBridgeAndUnusedRows() throws {
        let factory = factory()
        var sections: [WalletTransactionHistorySection] = []
        let firstChanges = try factory.merge(
            newItems: [
                CovHTxHistoryFixture.transaction("a", type: TransactionType.outgoing.rawValue, timestamp: 1_700_000_000),
                CovHTxHistoryFixture.transaction("b", type: TransactionType.outgoing.rawValue, timestamp: 1_700_000_100),
                CovHTxHistoryFixture.transaction("bridge", type: TransactionType.bridge.rawValue),
                CovHTxHistoryFixture.transaction("unused", type: TransactionType.unused.rawValue)
            ],
            into: &sections,
            locale: locale
        )
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections.first?.items.map(\.transaction.transactionId), ["a", "b"])
        XCTAssertEqual(firstChanges.count, 2)
        guard case .insert(0, _) = firstChanges[0], case .update(0, .insert(1, _), _) = firstChanges[1] else {
            return XCTFail("A new day is inserted, a second row of the same day updates it")
        }

        let later = try factory.merge(
            newItems: [
                CovHTxHistoryFixture.transaction("c", type: TransactionType.incoming.rawValue, timestamp: 1_700_000_200),
                CovHTxHistoryFixture.transaction("d", type: TransactionType.incoming.rawValue, timestamp: 1_600_000_000)
            ],
            into: &sections,
            locale: locale
        )
        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections.first?.items.count, 3)
        guard case .update(0, .insert(2, _), _) = later[0], case .insert(1, _) = later[1] else {
            return XCTFail("Existing days grow and older days are appended")
        }

        XCTAssertThrowsError(
            try factory.merge(newItems: [CovHTxHistoryFixture.transaction("x", type: "Teleport")], into: &sections, locale: locale)
        ) { error in
            guard case TransactionHistoryViewModelFactoryError.unsupportedType = error else {
                return XCTFail("Unexpected \(error)")
            }
        }
    }
}

final class CovHTxHistoryPresenterTests: XCTestCase {
    private func presenter(
        chain: ChainModel = CovHTxHistoryFixture.chain(),
        factory: WalletTransactionHistoryViewModelFactoryProtocol? = nil
    ) -> (WalletTransactionHistoryPresenter, CovHTxHistoryInputSpy, CovHTxHistoryWireframeSpy, CovHTxHistoryViewSpy) {
        let input = CovHTxHistoryInputSpy()
        let wireframe = CovHTxHistoryWireframeSpy()
        let view = CovHTxHistoryViewSpy()
        let presenter = WalletTransactionHistoryPresenter(
            interactor: input,
            wireframe: wireframe,
            viewModelFactory: factory ?? WalletTransactionHistoryViewModelFactory(
                balanceFormatterFactory: AssetBalanceFormatterFactory(),
                includesFeeInAmount: false,
                transactionTypes: [.incoming, .outgoing],
                chainAsset: ChainAsset(chain: chain, asset: CovHTxHistoryFixture.main),
                iconGenerator: UniversalIconGenerator()
            ),
            chainAsset: ChainAsset(chain: chain, asset: CovHTxHistoryFixture.main),
            logger: Logger.shared,
            localizationManager: LocalizationManager.shared
        )
        presenter.setup(with: view)
        return (presenter, input, wireframe, view)
    }

    func testModuleInputSwitchesAssetOrReloadsAndFiltersAreOfferedOnceKnown() {
        let (presenter, input, wireframe, view) = presenter()
        XCTAssertTrue(input.output === presenter)

        let other = ChainAsset(chain: CovHTxHistoryFixture.chain(id: "cov-other"), asset: CovHTxHistoryFixture.other)
        presenter.updateTransactionHistory(for: other)
        presenter.updateTransactionHistory(for: nil)
        XCTAssertEqual(input.changedAssets.map(\.chainAssetId), [other.chainAssetId])
        XCTAssertEqual(input.reloads, 1)

        presenter.didTapFiltersButton()
        XCTAssertTrue(wireframe.filters.isEmpty, "No filters before the interactor sends them")
        let filters = [FilterSet(title: "Show", items: WalletTransactionHistoryFilter.defaultFilters())]
        presenter.didReceive(filters: filters)
        presenter.didTapFiltersButton()
        XCTAssertEqual(wireframe.filters.count, 1)
        XCTAssertEqual(wireframe.filters.first?.first?.items.count, 4)

        presenter.didFinishWithFilters(filters: filters)
        XCTAssertEqual(input.appliedFilters.count, 1)
        XCTAssertEqual(view.starts, 1)

        presenter.didSelect(viewModel: CovHTxHistoryFixture.cell("selected"))
        XCTAssertEqual(wireframe.details.count, SelectedWalletSettings.shared.value == nil ? 0 : 1)
    }

    func testGiantSquidHistoryAllowsSeveralFiltersAndOtherHistoriesDoNot() throws {
        let squid = presenter(chain: CovHTxHistoryFixture.chain(history: "giantsquid"))
        squid.0.didReceive(pageData: AssetTransactionPageData(transactions: [
            CovHTxHistoryFixture.transaction("a", type: TransactionType.outgoing.rawValue)
        ]), reload: true)
        guard case let .reloaded(viewModel)? = squid.3.states.last else {
            return XCTFail("Expected reloaded rows")
        }
        XCTAssertEqual(viewModel.filtering, WalletTransactionHistoryViewFilterMode.multiple)

        let etherscan = presenter(chain: CovHTxHistoryFixture.chain(history: "etherscan"))
        etherscan.0.didReceive(pageData: AssetTransactionPageData(transactions: []), reload: false)
        guard case let .loaded(plain)? = etherscan.3.states.last else {
            return XCTFail("Expected loaded rows")
        }
        XCTAssertEqual(plain.filtering, WalletTransactionHistoryViewFilterMode.disabled)
    }

    func testAPageWithoutHistoryOrWithUndisplayableRowsFailsVisibly() {
        let noHistory = presenter(chain: CovHTxHistoryFixture.chain(history: nil))
        noHistory.0.didReceive(pageData: AssetTransactionPageData(transactions: []), reload: true)
        guard case .unsupported? = noHistory.3.states.last else {
            return XCTFail("A network without history says so")
        }
        XCTAssertEqual(noHistory.3.failures.count, 1)

        let broken = presenter()
        broken.0.didReceive(
            pageData: AssetTransactionPageData(transactions: [CovHTxHistoryFixture.transaction("x", type: "Teleport")]),
            reload: true
        )
        guard case .unavailable? = broken.3.states.last else {
            return XCTFail("Undisplayable rows must not look like an empty history")
        }
        XCTAssertEqual(broken.3.failures, [true])
        XCTAssertFalse(broken.0.loadNext())
    }
}

final class CovHTxHistoryFiltersTests: XCTestCase {
    func testFilterIdentitiesTitlesAndReset() {
        let defaults = WalletTransactionHistoryFilter.defaultFilters()
        XCTAssertEqual(defaults.map(\.id), ["transfer", "reward", "extrinsic", "swap"])
        XCTAssertTrue(defaults.allSatisfy(\.selected))
        XCTAssertEqual(defaults[3].title, "Swap")
        XCTAssertFalse(defaults[2].title.isEmpty)

        var filter = WalletTransactionHistoryFilter(type: .other)
        XCTAssertFalse(filter.selected)
        filter.reset()
        XCTAssertTrue(filter.selected)
    }

    func testViewFactoryAndContainerFiltersFollowTheNetwork() {
        func ids(_ sets: [FilterSet]) -> [String] {
            sets.flatMap { ($0.items as? [WalletTransactionHistoryFilter]) ?? [] }.map(\.id)
        }

        XCTAssertTrue(WalletTransactionHistoryViewFactory.transactionHistoryFilters(for: CovHTxHistoryFixture.chain(history: nil)).isEmpty)
        XCTAssertTrue(WalletTransactionHistoryViewFactory.transactionHistoryFilters(for: CovHTxHistoryFixture.chain(history: "etherscan")).isEmpty)
        XCTAssertEqual(ids(WalletTransactionHistoryViewFactory.transactionHistoryFilters(for: CovHTxHistoryFixture.chain())), ["transfer"])
        XCTAssertEqual(
            ids(WalletTransactionHistoryViewFactory.transactionHistoryFilters(for: CovHTxHistoryFixture.chain(options: [.polkaswap]))),
            ["swap", "transfer"]
        )
        XCTAssertEqual(
            ids(WalletTransactionHistoryViewFactory.transactionHistoryFilters(for: CovHTxHistoryFixture.chain(name: "SORA Mainnet"))),
            ["transfer", "reward"]
        )

        let container = WalletTransactionHistoryDependencyContainer(selectedAccount: AccountGenerator.generateMetaAccount())
        XCTAssertEqual(ids(container.transactionHistoryFilters(for: CovHTxHistoryFixture.chain())), ["transfer"])
        XCTAssertEqual(ids(container.transactionHistoryFilters(for: CovHTxHistoryFixture.chain(history: "etherscan"))), ["transfer", "extrinsic"])
        XCTAssertEqual(
            ids(container.transactionHistoryFilters(for: CovHTxHistoryFixture.chain(name: "SORA Mainnet", history: "subsquid"))),
            ["transfer", "reward", "extrinsic"]
        )
        XCTAssertEqual(
            ids(container.transactionHistoryFilters(for: CovHTxHistoryFixture.chain(history: "subsquid", options: [.polkaswap]))),
            ["swap", "transfer"]
        )
    }

    func testDependencyContainerRefusesNetworksWithoutAHistoryFactory() {
        let container = WalletTransactionHistoryDependencyContainer(selectedAccount: AccountGenerator.generateMetaAccount())
        let chain = CovHTxHistoryFixture.chain(history: nil)
        XCTAssertThrowsError(
            try container.createDependencies(for: ChainAsset(chain: chain, asset: CovHTxHistoryFixture.main), selectedAccount: AccountGenerator.generateMetaAccount())
        ) { error in
            guard case WalletTransactionHistoryDependencyContainerError.unsupported = error else {
                return XCTFail("Unexpected \(error)")
            }
        }
        XCTAssertNil(container.dependencies)

        let wallet = AccountGenerator.generateMetaAccount()
        let squid = ChainAsset(chain: CovHTxHistoryFixture.chain(id: "cov-h-squid-\(UUID().uuidString)"), asset: CovHTxHistoryFixture.main)
        XCTAssertNoThrow(try container.createDependencies(for: squid, selectedAccount: wallet))
        XCTAssertNotNil(container.dependencies?.historyService)
    }
}
