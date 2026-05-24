import XCTest
import UIKit
import BigInt
import FearlessFoundation
import SSFModels
import SSFPools
@testable import fearless

final class LiquidityPoolSupplyTests: XCTestCase {
    func testDidLoad_whenViewProvided_thenBootstrapsInteractor() {
        let fixture = makeFixture()
        let view = LiquidityPoolSupplyViewSpy()

        fixture.presenter.didLoad(view: view)

        XCTAssertTrue(fixture.interactor.output === fixture.presenter)
    }

    func testViewAppeared_whenNoAvailablePairs_thenLoadsInitialDataAndEstimatesFee() {
        let fixture = makeFixture(availablePairs: nil)
        let view = LiquidityPoolSupplyViewSpy()
        let expectation = expectation(description: "initial view updates delivered")
        view.onDidReceiveViewModel = { expectation.fulfill() }

        fixture.presenter.didLoad(view: view)
        fixture.presenter.handleViewAppeared()

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(fixture.interactor.fetchPoolsCallCount, 1)
        XCTAssertEqual(fixture.interactor.estimatedFeeCalls.count, 1)
        XCTAssertEqual(fixture.interactor.estimatedFeeCalls.last?.baseAssetAmount, .zero)
        XCTAssertEqual(fixture.viewModelFactory.lastSlippage, 0.5)
        XCTAssertNil(view.feeViewModel)
    }

    func testAmountChanges_whenAmountsUpdated_thenRefreshesFee() {
        let fixture = makeFixture()
        let view = LiquidityPoolSupplyViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.handleViewAppeared()
        fixture.presenter.didReceivePoolReserves(reserves: makeReserves())
        fixture.presenter.updateFromAmount(2)
        fixture.presenter.updateToAmount(3)

        XCTAssertEqual(fixture.interactor.estimatedFeeCalls.count, 3)
        XCTAssertEqual(fixture.interactor.estimatedFeeCalls.last?.baseAssetAmount, 1.5)
        XCTAssertEqual(fixture.interactor.estimatedFeeCalls.last?.targetAssetAmount, 3)
    }

    func testFeeAndApyOutputs_whenReceived_thenUpdateViewAndLoadingState() {
        let fixture = makeFixture()
        let view = LiquidityPoolSupplyViewSpy()
        let expectation = expectation(description: "fee update delivered")
        view.onDidReceiveNetworkFee = {
            if view.feeViewModel != nil {
                expectation.fulfill()
            }
        }

        fixture.presenter.didLoad(view: view)
        fixture.presenter.handleViewAppeared()
        fixture.presenter.didReceivePoolAPY(apyInfo: PoolApyInfo(apy: 12, poolId: "pool"))
        fixture.presenter.didReceiveFee(BigUInt(12))

        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(view.feeViewModel)
        XCTAssertEqual(fixture.viewModelFactory.lastApy?.apy, 12)
        XCTAssertTrue(view.loadingStates.contains(false))
    }

    func testPreview_whenInputsAreValid_thenRoutesToConfirmation() {
        let fixture = makeFixture()
        let view = LiquidityPoolSupplyViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.handleViewAppeared()
        fixture.presenter.didReceiveAccountInfo(
            result: .success(makeAccountInfo(free: 10_000)),
            for: fixture.baseChainAsset
        )
        fixture.presenter.didReceiveAccountInfo(
            result: .success(makeAccountInfo(free: 10_000)),
            for: fixture.targetChainAsset
        )
        fixture.presenter.didReceiveFee(BigUInt(1))
        fixture.presenter.updateFromAmount(2)
        fixture.presenter.updateToAmount(3)
        fixture.presenter.didTapPreviewButton()

        XCTAssertTrue(fixture.router.confirmationView === view)
        XCTAssertEqual(fixture.router.confirmationInputData?.baseAssetAmount, 2)
        XCTAssertEqual(fixture.router.confirmationInputData?.targetAssetAmount, 3)
        XCTAssertEqual(fixture.router.confirmationPair?.pairId, fixture.pair.pairId)
    }

    func testBackAndInfoActions_whenTapped_thenRouteThroughRouter() {
        let fixture = makeFixture()
        let view = LiquidityPoolSupplyViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didTapBackButton()
        fixture.presenter.didTapApyInfo()
        fixture.presenter.didTapFeeInfo()

        XCTAssertTrue(fixture.router.dismissedView === view)
        XCTAssertEqual(fixture.router.presentedInfoCount, 2)
    }

    private func makeFixture(
        availablePairs: [LiquidityPair]? = [makeLiquidityPair()]
    ) -> LiquidityPoolSupplyFixture {
        let interactor = LiquidityPoolSupplyInteractorInputSpy()
        let router = LiquidityPoolSupplyRouterSpy()
        let viewModelFactory = LiquidityPoolSupplyViewModelFactorySpy()
        let chain = makeLiquidityChain()
        let pair = makeLiquidityPair()
        let wallet = AccountGenerator.generateMetaAccount().replacingName("Wallet")
        let presenter = LiquidityPoolSupplyPresenter(
            interactor: interactor,
            router: router,
            liquidityPair: pair,
            localizationManager: LocalizationManager.shared,
            chain: chain,
            logger: LoggerSpy(),
            wallet: wallet,
            dataValidatingFactory: SendDataValidatingFactory(presentable: router),
            viewModelFactory: viewModelFactory,
            availablePairs: availablePairs,
            didSubmitTransactionClosure: { _ in }
        )

        return LiquidityPoolSupplyFixture(
            presenter: presenter,
            interactor: interactor,
            router: router,
            viewModelFactory: viewModelFactory,
            chain: chain,
            pair: pair,
            baseChainAsset: chain.chainAssets.first { $0.asset.currencyId == pair.baseAssetId }!,
            targetChainAsset: chain.chainAssets.first { $0.asset.currencyId == pair.targetAssetId }!
        )
    }
}

private struct LiquidityPoolSupplyFixture {
    let presenter: LiquidityPoolSupplyPresenter
    let interactor: LiquidityPoolSupplyInteractorInputSpy
    let router: LiquidityPoolSupplyRouterSpy
    let viewModelFactory: LiquidityPoolSupplyViewModelFactorySpy
    let chain: ChainModel
    let pair: LiquidityPair
    let baseChainAsset: ChainAsset
    let targetChainAsset: ChainAsset
}

private final class LiquidityPoolSupplyViewSpy: LiquidityPoolSupplyViewInput {
    let controller = UIViewController()
    let isSetup = true

    private(set) var fromViewModel: AssetBalanceViewModelProtocol?
    private(set) var toViewModel: AssetBalanceViewModelProtocol?
    private(set) var fromInputViewModel: IAmountInputViewModel?
    private(set) var toInputViewModel: IAmountInputViewModel?
    private(set) var feeViewModel: BalanceViewModelProtocol?
    private(set) var loadingStates: [Bool] = []
    private(set) var viewModel: LiquidityPoolSupplyViewModel?
    private(set) var swapQuoteReadyCount = 0

    var onDidReceiveViewModel: (() -> Void)?
    var onDidReceiveNetworkFee: (() -> Void)?

    func didReceiveSwapFrom(viewModel: AssetBalanceViewModelProtocol?) {
        fromViewModel = viewModel
    }

    func didReceiveSwapTo(viewModel: AssetBalanceViewModelProtocol?) {
        toViewModel = viewModel
    }

    func didReceiveSwapFrom(amountInputViewModel: IAmountInputViewModel?) {
        fromInputViewModel = amountInputViewModel
    }

    func didReceiveSwapTo(amountInputViewModel: IAmountInputViewModel?) {
        toInputViewModel = amountInputViewModel
    }

    func didReceiveNetworkFee(fee: BalanceViewModelProtocol?) {
        feeViewModel = fee
        onDidReceiveNetworkFee?()
    }

    func setButtonLoadingState(isLoading: Bool) {
        loadingStates.append(isLoading)
    }

    func didReceiveViewModel(_ viewModel: LiquidityPoolSupplyViewModel) {
        self.viewModel = viewModel
        onDidReceiveViewModel?()
    }

    func didReceiveSwapQuoteReady() {
        swapQuoteReadyCount += 1
    }
}

private final class LiquidityPoolSupplyInteractorInputSpy: LiquidityPoolSupplyInteractorInput {
    private(set) weak var output: LiquidityPoolSupplyInteractorOutput?
    private(set) var estimatedFeeCalls: [SupplyLiquidityInfo] = []
    private(set) var fetchPoolsCallCount = 0

    func setup(with output: LiquidityPoolSupplyInteractorOutput) {
        self.output = output
    }

    func estimateFee(supplyLiquidityInfo: SupplyLiquidityInfo) {
        estimatedFeeCalls.append(supplyLiquidityInfo)
    }

    func fetchPools() {
        fetchPoolsCallCount += 1
    }
}

private final class LiquidityPoolSupplyRouterSpy: LiquidityPoolSupplyRouterInput {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) weak var confirmationView: ControllerBackedProtocol?
    private(set) var confirmationPair: LiquidityPair?
    private(set) var confirmationInputData: LiquidityPoolSupplyConfirmInputData?
    private(set) var presentedInfoCount = 0
    private(set) var presentedError: Error?
    private(set) var presentedMessages: [(message: String?, title: String)] = []

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func showSelectAsset(
        from _: ControllerBackedProtocol?,
        wallet _: MetaAccountModel,
        chainAssets _: [ChainAsset]?,
        selectedAssetId _: AssetModel.Id?,
        contextTag _: Int?,
        output _: SelectAssetModuleOutput
    ) {}

    func showConfirmation(
        chain _: ChainModel,
        wallet _: MetaAccountModel,
        liquidityPair: LiquidityPair,
        inputData: LiquidityPoolSupplyConfirmInputData,
        didSubmitTransactionClosure _: @escaping (String) -> Void,
        from view: ControllerBackedProtocol?
    ) {
        confirmationPair = liquidityPair
        confirmationInputData = inputData
        confirmationView = view
    }

    func present(
        viewModel _: SheetAlertPresentableViewModel,
        from _: ControllerBackedProtocol?
    ) {}

    func present(
        message: String?,
        title: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {
        presentedMessages.append((message, title))
    }

    func presentInfo(
        message _: String?,
        title _: String,
        from _: ControllerBackedProtocol?
    ) {
        presentedInfoCount += 1
    }

    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        presentedError = error
        return true
    }
}

private final class LiquidityPoolSupplyViewModelFactorySpy: LiquidityPoolSupplyViewModelFactory {
    private(set) var lastSlippage: Decimal?
    private(set) var lastApy: PoolApyInfo?

    func buildViewModel(
        slippage: Decimal,
        apy: PoolApyInfo?,
        liquidityPair _: LiquidityPair,
        chain _: ChainModel
    ) -> LiquidityPoolSupplyViewModel {
        lastSlippage = slippage
        lastApy = apy

        return LiquidityPoolSupplyViewModel(
            slippageViewModel: TitleMultiValueViewModel(title: "\(slippage)", subtitle: nil),
            apyViewModel: nil,
            rewardTokenViewModel: nil,
            rewardTokenIconViewModel: nil
        )
    }
}

private func makeLiquidityPair() -> LiquidityPair {
    LiquidityPair(
        pairId: "xor-val",
        chainId: "sora-chain",
        baseAssetId: "xor",
        targetAssetId: "val"
    )
}

private func makeLiquidityChain() -> ChainModel {
    let pair = makeLiquidityPair()
    let node = ChainNodeModel(url: URL(string: "wss://sora.example")!, name: "Sora", apikey: nil)
    let base = makeAsset(id: "xor-asset", symbol: "xor", currencyId: pair.baseAssetId)
    let target = makeAsset(id: "val-asset", symbol: "val", currencyId: pair.targetAssetId)
    let reward = makeAsset(id: "pswap-asset", symbol: "pswap", currencyId: pair.rewardAssetId, isUtility: true)

    return ChainModel(
        rank: nil,
        disabled: false,
        chainId: "sora-chain",
        paraId: nil,
        name: "Sora Mainnet",
        assets: [base, target, reward],
        xcm: nil,
        nodes: [node],
        addressPrefix: 69,
        icon: nil,
        options: [.polkaswap],
        iosMinAppVersion: nil,
        identityChain: nil
    )
}

private func makeAsset(
    id: String,
    symbol: String,
    currencyId: String,
    isUtility: Bool = false
) -> AssetModel {
    AssetModel(
        id: id,
        name: symbol.uppercased(),
        symbol: symbol,
        precision: 2,
        currencyId: currencyId,
        existentialDeposit: "0",
        color: "#FFFFFF",
        isUtility: isUtility,
        isNative: isUtility
    )
}

private func makeReserves() -> PolkaswapPoolReservesInfo {
    PolkaswapPoolReservesInfo(
        reserves: PolkaswapPoolReserves(reserves: BigUInt(100), fee: BigUInt(200)),
        poolId: "xor-val"
    )
}

private func makeAccountInfo(free: BigUInt) -> AccountInfo {
    AccountInfo(
        nonce: 0,
        consumers: 0,
        providers: 0,
        data: AccountData(free: free, reserved: 0, frozen: 0, flags: 0)
    )
}

private final class LoggerSpy: LoggerProtocol {
    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message _: String, file _: String, function _: String, line _: Int) {}
    func customError(error _: Error, file _: String, function _: String, line _: Int) {}
}
