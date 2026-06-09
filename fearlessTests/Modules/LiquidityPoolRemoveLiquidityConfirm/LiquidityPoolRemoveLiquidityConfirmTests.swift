import XCTest
import UIKit
import BigInt
import FearlessFoundation
import SSFModels
import SSFPools
@testable import fearless

final class LiquidityPoolRemoveLiquidityConfirmTests: XCTestCase {
    func testDidLoad_whenViewProvided_thenBootstrapsInteractorAndBuildsConfirmViewModel() {
        let fixture = makeFixture()
        let view = LiquidityPoolRemoveLiquidityConfirmViewSpy()
        let expectation = expectation(description: "confirm view model delivered")
        view.onDidReceiveConfirmViewModel = { expectation.fulfill() }

        fixture.presenter.didLoad(view: view)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(fixture.interactor.output === fixture.presenter)
        XCTAssertNotNil(view.confirmViewModel)
    }

    func testViewAppeared_whenRemoveInfoAvailable_thenEstimatesFee() {
        let fixture = makeFixture()
        let view = LiquidityPoolRemoveLiquidityConfirmViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.handleViewAppeared()

        XCTAssertEqual(fixture.interactor.estimatedFeeCalls.count, 1)
        XCTAssertEqual(fixture.interactor.estimatedFeeCalls.last?.baseAssetAmount, .zero)
        XCTAssertEqual(fixture.interactor.estimatedFeeCalls.last?.targetAssetAmount, .zero)
        XCTAssertNil(view.feeViewModel)
    }

    func testConfirm_whenTapped_thenSubmitsAndStartsLoading() {
        let fixture = makeFixture()
        let view = LiquidityPoolRemoveLiquidityConfirmViewSpy()
        let expectation = expectation(description: "loading state delivered")
        var fulfilled = false
        view.onSetButtonLoadingState = {
            guard !fulfilled else { return }
            fulfilled = true
            expectation.fulfill()
        }

        fixture.presenter.didLoad(view: view)
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
        let view = LiquidityPoolRemoveLiquidityConfirmViewSpy()
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

    func testFeeAndErrors_whenReceived_thenUpdateViewAndRouter() {
        let fixture = makeFixture()
        let view = LiquidityPoolRemoveLiquidityConfirmViewSpy()
        let expectation = expectation(description: "fee delivered")
        view.onDidReceiveNetworkFee = {
            if view.feeViewModel != nil {
                expectation.fulfill()
            }
        }

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didReceiveFee(BigUInt(12))
        fixture.presenter.didReceiveSubmitError(error: TestError.expected)
        fixture.presenter.didReceiveFeeError(TestError.expected)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(view.feeViewModel)
        XCTAssertTrue(fixture.router.presentedError is TestError)
        XCTAssertEqual(fixture.logger.errorsCount, 1)
    }

    func testBackAndInfo_whenTapped_thenRouteThroughRouter() {
        let fixture = makeFixture()
        let view = LiquidityPoolRemoveLiquidityConfirmViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didTapBackButton()
        fixture.presenter.didTapFeeInfo()

        XCTAssertTrue(fixture.router.dismissedView === view)
        XCTAssertEqual(fixture.router.presentedInfoCount, 1)
    }

    private func makeFixture(
        didSubmitTransactionClosure: @escaping (String) -> Void = { _ in }
    ) -> LiquidityPoolRemoveLiquidityConfirmFixture {
        let interactor = LiquidityPoolRemoveLiquidityInteractorInputSpy()
        let router = LiquidityPoolRemoveLiquidityRouterSpy()
        let logger = LoggerSpy()
        let chain = makeLiquidityChain()
        let pair = makeLiquidityPair()
        let presenter = LiquidityPoolRemoveLiquidityPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            wallet: AccountGenerator.generateMetaAccount().replacingName("Wallet"),
            logger: logger,
            chain: chain,
            liquidityPair: pair,
            dataValidatingFactory: SendDataValidatingFactory(presentable: router),
            confirmViewModelFactory: LiquidityPoolSupplyConfirmViewModelFactorySpy(),
            removeInfo: makeRemoveInfo(),
            didSubmitTransactionClosure: didSubmitTransactionClosure
        )

        return LiquidityPoolRemoveLiquidityConfirmFixture(
            presenter: presenter,
            interactor: interactor,
            router: router,
            logger: logger,
            chain: chain,
            pair: pair
        )
    }
}

private struct LiquidityPoolRemoveLiquidityConfirmFixture {
    let presenter: LiquidityPoolRemoveLiquidityPresenter
    let interactor: LiquidityPoolRemoveLiquidityInteractorInputSpy
    let router: LiquidityPoolRemoveLiquidityRouterSpy
    let logger: LoggerSpy
    let chain: ChainModel
    let pair: LiquidityPair
}

private final class LiquidityPoolRemoveLiquidityConfirmViewSpy: LiquidityPoolRemoveLiquidityConfirmViewInput {
    let controller = UIViewController()
    let isSetup = true

    private(set) var feeViewModel: BalanceViewModelProtocol?
    private(set) var loadingStates: [Bool] = []
    private(set) var confirmViewModel: LiquidityPoolSupplyConfirmViewModel?

    var onDidReceiveNetworkFee: (() -> Void)?
    var onSetButtonLoadingState: (() -> Void)?
    var onDidReceiveConfirmViewModel: (() -> Void)?

    func didReceiveNetworkFee(fee: BalanceViewModelProtocol?) {
        feeViewModel = fee
        onDidReceiveNetworkFee?()
    }

    func setButtonLoadingState(isLoading: Bool) {
        loadingStates.append(isLoading)
        onSetButtonLoadingState?()
    }

    func didReceiveConfirmViewModel(_ viewModel: LiquidityPoolSupplyConfirmViewModel?) {
        confirmViewModel = viewModel
        onDidReceiveConfirmViewModel?()
    }
}

private final class LiquidityPoolRemoveLiquidityInteractorInputSpy: LiquidityPoolRemoveLiquidityInteractorInput {
    private(set) weak var output: LiquidityPoolRemoveLiquidityInteractorOutput?
    private(set) var estimatedFeeCalls: [RemoveLiquidityInfo] = []
    private(set) var submitCalls: [RemoveLiquidityInfo] = []

    func setup(with output: LiquidityPoolRemoveLiquidityInteractorOutput) {
        self.output = output
    }

    func estimateFee(removeLiquidityInfo: RemoveLiquidityInfo) {
        estimatedFeeCalls.append(removeLiquidityInfo)
    }

    func submit(removeLiquidityInfo: RemoveLiquidityInfo) {
        submitCalls.append(removeLiquidityInfo)
    }
}

private final class LiquidityPoolRemoveLiquidityRouterSpy: LiquidityPoolRemoveLiquidityRouterInput {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) weak var confirmationView: ControllerBackedProtocol?
    private(set) weak var completedView: ControllerBackedProtocol?
    private(set) var completedTitle: String?
    private(set) var confirmationPair: LiquidityPair?
    private(set) var confirmationInfo: RemoveLiquidityInfo?
    private(set) var presentedInfoCount = 0
    private(set) var presentedError: Error?
    private(set) var presentedMessages: [(message: String?, title: String)] = []

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func showConfirmation(
        chain _: ChainModel,
        wallet _: MetaAccountModel,
        liquidityPair: LiquidityPair,
        info: RemoveLiquidityInfo,
        didSubmitTransactionClosure _: @escaping (String) -> Void,
        from view: ControllerBackedProtocol?
    ) {
        confirmationPair = liquidityPair
        confirmationInfo = info
        confirmationView = view
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

private func makeRemoveInfo() -> RemoveLiquidityInfo {
    RemoveLiquidityInfo(
        dexId: "0",
        baseAsset: PooledAssetInfo(id: "xor", precision: 2),
        targetAsset: PooledAssetInfo(id: "val", precision: 2),
        baseAssetAmount: 2,
        targetAssetAmount: 3,
        baseAssetReserves: 10,
        totalIssuances: 20,
        slippage: 0.5
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
