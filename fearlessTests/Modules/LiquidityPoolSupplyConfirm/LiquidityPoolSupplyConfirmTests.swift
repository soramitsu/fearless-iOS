import XCTest
import UIKit
import BigInt
import FearlessFoundation
import SSFModels
import SSFPools
@testable import fearless

final class LiquidityPoolSupplyConfirmTests: XCTestCase {
    func testDidLoad_whenViewProvided_thenBootstrapsInteractor() {
        let fixture = makeFixture()
        let view = LiquidityPoolSupplyConfirmViewSpy()

        fixture.presenter.didLoad(view: view)

        XCTAssertTrue(fixture.interactor.output === fixture.presenter)
    }

    func testViewAppeared_whenCalled_thenBuildsViewModelsAndEstimatesFee() {
        let fixture = makeFixture()
        let view = LiquidityPoolSupplyConfirmViewSpy()
        let expectation = expectation(description: "view model delivered")
        view.onDidReceiveConfirmationViewModel = { expectation.fulfill() }

        fixture.presenter.didLoad(view: view)
        fixture.presenter.handleViewAppeared()

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(fixture.interactor.estimatedFeeCalls.count, 1)
        XCTAssertEqual(fixture.interactor.estimatedFeeCalls.last?.baseAssetAmount, 2)
        XCTAssertEqual(fixture.interactor.estimatedFeeCalls.last?.targetAssetAmount, 3)
        XCTAssertNotNil(view.viewModel)
        XCTAssertNotNil(view.confirmationViewModel)
        XCTAssertNil(view.feeViewModel)
    }

    func testConfirm_whenTapped_thenSubmitsAndStartsLoading() {
        let fixture = makeFixture()
        let view = LiquidityPoolSupplyConfirmViewSpy()
        let expectation = expectation(description: "loading state delivered")
        var fulfilled = false
        view.onSetButtonLoadingState = {
            guard !fulfilled else { return }
            fulfilled = true
            expectation.fulfill()
        }

        fixture.presenter.didLoad(view: view)
        fixture.presenter.handleViewAppeared()
        fixture.presenter.didTapConfirmButton()

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(fixture.interactor.submitCalls.count, 1)
        XCTAssertEqual(fixture.interactor.submitCalls.last?.baseAssetAmount, 2)
        XCTAssertEqual(fixture.interactor.submitCalls.last?.targetAssetAmount, 3)
        XCTAssertTrue(view.loadingStates.contains(true))
    }

    func testTransactionHash_whenReceived_thenCompletesAndReportsHash() {
        var submittedHash: String?
        let fixture = makeFixture(didSubmitTransactionClosure: { submittedHash = $0 })
        let view = LiquidityPoolSupplyConfirmViewSpy()
        let expectation = expectation(description: "loading state delivered")
        view.onSetButtonLoadingState = { expectation.fulfill() }

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didReceiveTransactionHash("0xhash")

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(submittedHash, "0xhash")
        XCTAssertTrue(fixture.router.completedView === view)
        XCTAssertEqual(fixture.router.completedTitle, "0xhash")
        XCTAssertTrue(view.loadingStates.contains(false))
    }

    func testErrorsAndInfo_whenReceived_thenRouteThroughRouterAndLogger() {
        let fixture = makeFixture()
        let view = LiquidityPoolSupplyConfirmViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didTapBackButton()
        fixture.presenter.didTapApyInfo()
        fixture.presenter.didTapFeeInfo()
        fixture.presenter.didReceiveSubmitError(error: TestError.expected)
        fixture.presenter.didReceivePoolApyError(error: TestError.expected)
        fixture.presenter.didReceiveFeeError(TestError.expected)

        XCTAssertTrue(fixture.router.dismissedView === view)
        XCTAssertEqual(fixture.router.presentedInfoCount, 2)
        XCTAssertTrue(fixture.router.presentedError is TestError)
        XCTAssertEqual(fixture.logger.errorsCount, 2)
    }

    func testFeeOutput_whenReceived_thenUpdatesFeeAndLoadingState() {
        let fixture = makeFixture()
        let view = LiquidityPoolSupplyConfirmViewSpy()
        let expectation = expectation(description: "fee view model delivered")
        view.onDidReceiveNetworkFee = {
            if view.feeViewModel != nil {
                expectation.fulfill()
            }
        }

        fixture.presenter.didLoad(view: view)
        fixture.presenter.handleViewAppeared()
        fixture.presenter.didReceiveFee(BigUInt(12))

        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(view.feeViewModel)
        XCTAssertTrue(view.loadingStates.contains(false))
    }

    private func makeFixture(
        didSubmitTransactionClosure: @escaping (String) -> Void = { _ in }
    ) -> LiquidityPoolSupplyConfirmFixture {
        let interactor = LiquidityPoolSupplyConfirmInteractorInputSpy()
        let router = LiquidityPoolSupplyConfirmRouterSpy()
        let logger = LoggerSpy()
        let viewModelFactory = LiquidityPoolSupplyConfirmViewModelFactorySpy()
        let chain = makeLiquidityChain()
        let pair = makeLiquidityPair()
        let presenter = LiquidityPoolSupplyConfirmPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            dataValidatingFactory: SendDataValidatingFactory(presentable: router),
            logger: logger,
            liquidityPair: pair,
            chain: chain,
            inputData: LiquidityPoolSupplyConfirmInputData(
                baseAssetAmount: 2,
                targetAssetAmount: 3,
                slippageTolerance: 0.5,
                availablePools: [pair]
            ),
            wallet: AccountGenerator.generateMetaAccount().replacingName("Wallet"),
            viewModelFactory: viewModelFactory,
            didSubmitTransactionClosure: didSubmitTransactionClosure
        )

        return LiquidityPoolSupplyConfirmFixture(
            presenter: presenter,
            interactor: interactor,
            router: router,
            logger: logger,
            viewModelFactory: viewModelFactory,
            chain: chain,
            pair: pair
        )
    }
}

private struct LiquidityPoolSupplyConfirmFixture {
    let presenter: LiquidityPoolSupplyConfirmPresenter
    let interactor: LiquidityPoolSupplyConfirmInteractorInputSpy
    let router: LiquidityPoolSupplyConfirmRouterSpy
    let logger: LoggerSpy
    let viewModelFactory: LiquidityPoolSupplyConfirmViewModelFactorySpy
    let chain: ChainModel
    let pair: LiquidityPair
}

private final class LiquidityPoolSupplyConfirmViewSpy: LiquidityPoolSupplyConfirmViewInput {
    let controller = UIViewController()
    let isSetup = true

    private(set) var feeViewModel: BalanceViewModelProtocol?
    private(set) var loadingStates: [Bool] = []
    private(set) var viewModel: LiquidityPoolSupplyViewModel?
    private(set) var confirmationViewModel: LiquidityPoolSupplyConfirmViewModel?

    var onDidReceiveNetworkFee: (() -> Void)?
    var onSetButtonLoadingState: (() -> Void)?
    var onDidReceiveConfirmationViewModel: (() -> Void)?

    func didReceiveNetworkFee(fee: BalanceViewModelProtocol?) {
        feeViewModel = fee
        onDidReceiveNetworkFee?()
    }

    func setButtonLoadingState(isLoading: Bool) {
        loadingStates.append(isLoading)
        onSetButtonLoadingState?()
    }

    func didReceiveViewModel(_ viewModel: LiquidityPoolSupplyViewModel) {
        self.viewModel = viewModel
    }

    func didReceiveConfirmationViewModel(_ viewModel: LiquidityPoolSupplyConfirmViewModel?) {
        confirmationViewModel = viewModel
        onDidReceiveConfirmationViewModel?()
    }
}

private final class LiquidityPoolSupplyConfirmInteractorInputSpy: LiquidityPoolSupplyConfirmInteractorInput {
    private(set) weak var output: LiquidityPoolSupplyConfirmInteractorOutput?
    private(set) var estimatedFeeCalls: [SupplyLiquidityInfo] = []
    private(set) var submitCalls: [SupplyLiquidityInfo] = []

    func setup(with output: LiquidityPoolSupplyConfirmInteractorOutput) {
        self.output = output
    }

    func estimateFee(supplyLiquidityInfo: SupplyLiquidityInfo) {
        estimatedFeeCalls.append(supplyLiquidityInfo)
    }

    func submit(supplyLiquidityInfo: SupplyLiquidityInfo) {
        submitCalls.append(supplyLiquidityInfo)
    }
}

private final class LiquidityPoolSupplyConfirmRouterSpy: LiquidityPoolSupplyConfirmRouterInput {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) weak var completedView: ControllerBackedProtocol?
    private(set) var completedTitle: String?
    private(set) var presentedInfoCount = 0
    private(set) var presentedError: Error?
    private(set) var presentedMessages: [(message: String?, title: String)] = []

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func complete(
        on view: ControllerBackedProtocol?,
        title: String,
        chainAsset _: ChainAsset
    ) {
        completedView = view
        completedTitle = title
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

private final class LiquidityPoolSupplyConfirmViewModelFactorySpy: LiquidityPoolSupplyConfirmViewModelFactory {
    func buildViewModel(
        slippage: Decimal,
        apy _: PoolApyInfo?,
        liquidityPair _: LiquidityPair,
        chain _: ChainModel
    ) -> LiquidityPoolSupplyViewModel {
        LiquidityPoolSupplyViewModel(
            slippageViewModel: TitleMultiValueViewModel(title: "\(slippage)", subtitle: nil),
            apyViewModel: nil,
            rewardTokenViewModel: nil,
            rewardTokenIconViewModel: nil
        )
    }

    func buildViewModel(
        baseAssetAmount: Decimal,
        targetAssetAmount: Decimal,
        liquidityPair _: LiquidityPair,
        chain _: ChainModel,
        locale _: Locale
    ) -> LiquidityPoolSupplyConfirmViewModel? {
        LiquidityPoolSupplyConfirmViewModel(
            amountsText: NSAttributedString(string: "\(baseAssetAmount)-\(targetAssetAmount)"),
            doubleImageViewViewModel: PolkaswapDoubleSymbolViewModel(
                leftViewModel: nil,
                rightViewModel: nil,
                leftShadowColor: nil,
                rightShadowColor: nil
            )
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

private final class LoggerSpy: LoggerProtocol {
    private(set) var errorsCount = 0

    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message _: String, file _: String, function _: String, line _: Int) {}

    func customError(error _: Error, file _: String, function _: String, line _: Int) {
        errorsCount += 1
    }
}

private enum TestError: Error {
    case expected
}
