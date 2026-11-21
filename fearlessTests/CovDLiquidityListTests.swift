import BigInt
import Foundation
import SoraFoundation
import SSFModels
import SSFPolkaswap
import SSFPools
import SSFStorageQueryKit
import UIKit
import XCTest

@testable import fearless

final class CovDListRouterSpy: LiquidityPoolsListRouterInput {
    private(set) var detailInputs: [LiquidityPoolDetailsInput] = []
    private(set) var dismissCount = 0
    private(set) var submitClosures: [(String) -> Void] = []

    func showPoolDetails(
        assetIdPair _: AssetIdPair,
        chain _: ChainModel,
        wallet _: MetaAccountModel,
        input: LiquidityPoolDetailsInput,
        didSubmitTransactionClosure: @escaping (String) -> Void,
        from _: ControllerBackedProtocol?
    ) {
        detailInputs.append(input)
        submitClosures.append(didSubmitTransactionClosure)
    }

    func dismiss(view _: ControllerBackedProtocol?) { dismissCount += 1 }
}

final class CovDListModuleOutputSpy: LiquidityPoolsListModuleOutput {
    private(set) var moreUser = 0
    private(set) var moreAvailable = 0
    private(set) var showUser: [Bool] = []
    private(set) var counts: [Int] = []
    private(set) var hashes: [String] = []

    func didTapMoreUserPools() { moreUser += 1 }
    func didTapMoreAvailablePools() { moreAvailable += 1 }
    func shouldShowUserPools(_ shouldShow: Bool) { showUser.append(shouldShow) }
    func didReceiveUserPoolCount(_ userPoolsCount: Int) { counts.append(userPoolsCount) }
    func didSubmitTransaction(transactionHash: String) { hashes.append(transactionHash) }
}

final class CovDUserPoolsInteractorSpy: UserLiquidityPoolsListInteractorInput {
    private(set) var fetchCount = 0
    private(set) var cancelCount = 0
    private(set) weak var output: UserLiquidityPoolsListInteractorOutput?

    func setup(with output: UserLiquidityPoolsListInteractorOutput) { self.output = output }
    func fetchPools() { fetchCount += 1 }
    func cancelTasks() { cancelCount += 1 }
}

final class CovDAvailablePoolsInteractorSpy: AvailableLiquidityPoolsListInteractorInput {
    private(set) var fetchCount = 0
    private(set) var cancelCount = 0
    private(set) weak var output: AvailableLiquidityPoolsListInteractorOutput?

    func setup(with output: AvailableLiquidityPoolsListInteractorOutput) { self.output = output }
    func fetchPools() { fetchCount += 1 }
    func cancelTasks() { cancelCount += 1 }
}

final class CovDLiquidityListTests: XCTestCase {
    typealias CovDF = CovDLiquidityFixtures
    private var window: UIWindow?

    override func tearDown() {
        CovDFixtures.tearDown(window)
        window = nil
        super.tearDown()
    }

    private let reservesHex = "0x" + String(repeating: "ab", count: 32)

    private func secondPair(_ chain: ChainModel) -> LiquidityPair {
        LiquidityPair(pairId: "\(CovDF.xor)-\(CovDF.pswap)", chainId: chain.chainId, baseAssetId: CovDF.xor, targetAssetId: CovDF.pswap)
    }

    private func reserves() -> CachedStorageResponse<[PolkaswapPoolReservesInfo]> {
        CachedStorageResponse(value: [
            CovDLiquidityReserves.make(poolId: "\(CovDF.xor)-\(CovDF.val)", reserves: CovDF.planks(100), fee: CovDF.planks(200))
        ], type: .remote)
    }

    private func address(_ chain: ChainModel) throws -> String {
        try AddressFactory.address(for: try Data(hexStringSSF: reservesHex), chain: chain)
    }

    private func cell(_ controller: LiquidityPoolsListViewController, row: Int) throws -> LiquidityPoolListCell {
        let table = controller.rootView.tableView
        let cell = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: row, section: 0)) as? LiquidityPoolListCell)
        controller.tableView(table, willDisplay: cell, forRowAt: IndexPath(row: row, section: 0))
        return cell
    }

    func testAvailablePoolsFullListShowsLoadingThenSortedFilteredPools() throws {
        let chain = CovDF.chain()
        let router = CovDListRouterSpy()
        let interactor = CovDAvailablePoolsInteractorSpy()
        let output = CovDListModuleOutputSpy()
        let presenter = AvailableLiquidityPoolsListPresenter(
            logger: Logger.shared,
            interactor: interactor,
            router: router,
            chain: chain,
            wallet: CovDFixtures.wallet(),
            viewModelFactory: AvailableLiquidityPoolsListViewModelFactoryDefault(
                modelFactory: LiquidityPoolsModelFactoryDefault(),
                assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
            ),
            localizationManager: LocalizationManager.shared,
            moduleOutput: output,
            type: .full
        )
        let controller = LiquidityPoolsListViewController(output: presenter, localizationManager: LocalizationManager.shared)
        window = try CovDFixtures.host(controller)
        XCTAssertTrue(interactor.output === presenter)
        XCTAssertEqual(interactor.fetchCount, 1)
        let table = controller.rootView.tableView
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 20)
        XCTAssertEqual(controller.tableView(table, heightForRowAt: IndexPath(row: 0, section: 0)), 44)
        XCTAssertFalse(controller.rootView.searchTextField.isHidden)
        XCTAssertTrue(controller.rootView.moreButton.isHidden)

        presenter.didReceiveLiquidityPairs(pairs: [])
        var pair = CovDF.pair(chain)
        pair.reservesId = reservesHex
        presenter.didReceiveLiquidityPairs(pairs: [secondPair(chain), pair])
        presenter.didReceivePoolsReserves(reserves: reserves())
        presenter.didReceivePoolsAPY(apy: [PoolApyInfo(poolId: try address(chain), apy: 15)])
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 2)
        let first = try cell(controller, row: 0)
        XCTAssertEqual(first.tokenPairNameLabel.text, "XOR-VAL")
        XCTAssertTrue(first.reservesLabel.text?.contains("TVL") == true)
        XCTAssertNotNil(first.apyLabel.text)
        XCTAssertEqual(try cell(controller, row: 1).tokenPairNameLabel.text, "XOR-PSWAP")

        presenter.searchTextDidChanged("pswap")
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 1)
        presenter.searchTextDidChanged(nil)
        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(router.detailInputs.count, 1)
        XCTAssertFalse(router.detailInputs[0].isUserPool)
        XCTAssertEqual(router.detailInputs[0].apyInfo?.apy, 15)
        XCTAssertEqual(router.detailInputs[0].availablePairs?.count, 2)
        router.submitClosures.first?("0xhash")
        XCTAssertEqual(output.hashes, ["0xhash"])

        presenter.didTapMoreButton()
        XCTAssertEqual(output.moreAvailable, 1)
        controller.rootView.backButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(router.dismissCount, 1)
        XCTAssertEqual(interactor.cancelCount, 1)
        presenter.handleRefreshControlEvent()
        presenter.refreshData()
        presenter.resetTasks()
        XCTAssertEqual(interactor.fetchCount, 3)
        XCTAssertEqual(interactor.cancelCount, 2)
        presenter.didReceiveLiquidityPairsError(error: CovDTestError.offline)
        presenter.didReceivePoolsReservesError(error: CovDTestError.offline)
        presenter.didReceivePoolsApyError(error: CovDTestError.offline)
        presenter.applyLocalization()
        controller.applyLocalization()
        presenter.didTapOn(viewModel: LiquidityPoolListCellModel(
            tokenPairIconsVieWModel: TokenPairsIconViewModel(firstTokenIconViewModel: nil, secondTokenIconViewModel: nil),
            tokenPairNameLabelText: nil, rewardTokenNameLabelText: nil, apyLabelText: nil,
            stakingStatusLabelText: nil, reservesLabelText: nil, sortValue: 0, liquidityPair: nil
        ))
        XCTAssertEqual(router.detailInputs.count, 1)
    }

    func testUserPoolsEmbedListReportsCountsAndOpensUserDetails() throws {
        let chain = CovDF.chain()
        let router = CovDListRouterSpy()
        let interactor = CovDUserPoolsInteractorSpy()
        let output = CovDListModuleOutputSpy()
        let presenter = UserLiquidityPoolsListPresenter(
            logger: Logger.shared,
            interactor: interactor,
            router: router,
            chain: chain,
            wallet: CovDFixtures.wallet(),
            viewModelFactory: UserLiquidityPoolsListViewModelFactoryDefault(
                modelFactory: LiquidityPoolsModelFactoryDefault(),
                assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
            ),
            localizationManager: LocalizationManager.shared,
            moduleOutput: output,
            type: .embed
        )
        let controller = LiquidityPoolsListViewController(output: presenter, localizationManager: LocalizationManager.shared)
        window = try CovDFixtures.host(controller)
        XCTAssertEqual(interactor.fetchCount, 1)
        let table = controller.rootView.tableView

        presenter.didReceiveUserPools(accountPools: [])
        XCTAssertEqual(output.showUser, [false])
        XCTAssertEqual(output.counts, [0])
        // Split into typed steps: one expression with both ternaries and the literals took the hosted
        // runner's compiler (Xcode 26.6) past its type-checking time limit.
        let pools: [AccountPool] = (0 ..< 7).map { (index: Int) -> AccountPool in
            let isFirst: Bool = index == 0
            let poolId: String = isFirst ? "\(CovDF.xor)-\(CovDF.val)" : "pool-\(index)"
            let reservesId: String? = isFirst ? reservesHex : nil
            let basePooled = Decimal(index + 1)
            return AccountPool(
                poolId: poolId, accountId: "0xaccount", chainId: chain.chainId,
                baseAssetId: CovDF.xor, targetAssetId: CovDF.val, baseAssetPooled: basePooled,
                targetAssetPooled: Decimal(2), accountPoolShare: Decimal(1), reservesId: reservesId
            )
        }
        presenter.didReceiveUserPools(accountPools: pools)
        presenter.didReceivePoolsReserves(reserves: reserves())
        presenter.didReceivePoolsAPY(apy: [PoolApyInfo(poolId: try address(chain), apy: 4)])
        presenter.didReceiveLiquidityPairs(pools: [CovDF.pair(chain)])
        XCTAssertEqual(output.showUser.last, true)
        XCTAssertEqual(output.counts.last, 5)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 5)
        XCTAssertFalse(controller.rootView.moreButton.isHidden)
        XCTAssertTrue(controller.rootView.searchTextField.isHidden)
        let top = try cell(controller, row: 0)
        XCTAssertEqual(top.tokenPairNameLabel.text, "XOR-VAL")
        XCTAssertEqual(top.stakingStatusLabel.text, "1 VAL - 2 VAL")
        XCTAssertTrue(top.reservesLabel.text?.contains("TVL") == true)

        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        let input = try XCTUnwrap(router.detailInputs.first)
        XCTAssertTrue(input.isUserPool)
        XCTAssertEqual(input.accountPool?.poolId, "\(CovDF.xor)-\(CovDF.val)")
        XCTAssertEqual(input.apyInfo?.apy, 4)
        XCTAssertEqual(input.availablePairs?.count, 7)
        router.submitClosures.first?("0xuser")
        XCTAssertEqual(output.hashes, ["0xuser"])

        presenter.searchTextDidChanged("zzz")
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 0)
        controller.rootView.moreButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.moreUser, 1)
        presenter.didTapBackButton()
        presenter.handleRefreshControlEvent()
        presenter.refreshData()
        presenter.resetTasks()
        XCTAssertEqual(router.dismissCount, 1)
        XCTAssertEqual(interactor.fetchCount, 3)
        XCTAssertEqual(interactor.cancelCount, 2)
        presenter.didReceiveLiquidityPairsError(error: CovDTestError.offline)
        presenter.didReceivePoolsReservesError(error: CovDTestError.offline)
        presenter.didReceivePoolsApyError(error: CovDTestError.offline)
        presenter.didReceiveUserPoolsError(error: CovDTestError.offline)
        presenter.applyLocalization()
    }

    func testFactoriesSkipPairsWithUnknownAssetsAndBuildLoadingRows() {
        let chain = CovDF.chain()
        let unknown = LiquidityPair(pairId: "x", chainId: chain.chainId, baseAssetId: "0xunknown", targetAssetId: CovDF.val)
        let available = AvailableLiquidityPoolsListViewModelFactoryDefault(
            modelFactory: LiquidityPoolsModelFactoryDefault(),
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        )
        let embed = available.buildViewModel(
            pairs: [unknown], reserves: nil, apyInfos: nil, chain: chain, locale: Locale(identifier: "en_US"),
            wallet: CovDFixtures.wallet(), type: .embed, searchText: ""
        )
        XCTAssertEqual(embed.poolViewModels?.count, 0)
        XCTAssertTrue(embed.moreButtonVisible)
        XCTAssertTrue(embed.isEmbed)
        XCTAssertFalse(embed.refreshAvailable)
        let loading = available.buildLoadingViewModel(type: .embed, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(loading.poolViewModels?.count, 20)
        XCTAssertNil(loading.poolViewModels?.first?.liquidityPair)
        XCTAssertFalse(loading.titleLabelText.isEmpty)

        let user = UserLiquidityPoolsListViewModelFactoryDefault(
            modelFactory: LiquidityPoolsModelFactoryDefault(),
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        ).buildViewModel(
            accountPools: [AccountPool(poolId: "u", accountId: "a", chainId: chain.chainId, baseAssetId: "0xunknown", targetAssetId: CovDF.val)],
            reserves: nil, apyInfos: nil, chain: chain, locale: Locale(identifier: "en_US"),
            wallet: CovDFixtures.wallet(), type: .full, searchText: nil
        )
        XCTAssertEqual(user.poolViewModels?.count, 0)
        XCTAssertFalse(user.moreButtonVisible)
        XCTAssertTrue(user.backgroundVisible)
    }
}
