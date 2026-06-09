import XCTest
import UIKit
import BigInt
import FearlessFoundation
import SSFModels
import SSFPools
@testable import fearless

final class LiquidityPoolRemoveLiquidityTests: XCTestCase {
    func testDidLoad_whenViewProvided_thenBootstrapsInteractor() {
        let fixture = makeFixture()
        let view = LiquidityPoolRemoveLiquidityViewSpy()

        fixture.presenter.didLoad(view: view)

        XCTAssertTrue(fixture.interactor.output === fixture.presenter)
    }

    func testViewAppearedAndPoolData_whenReady_thenEstimatesFeeAndReleasesLoadingState() {
        let fixture = makeFixture()
        let view = LiquidityPoolRemoveLiquidityViewSpy()
        let expectation = expectation(description: "quote ready delivered")
        view.onDidReceiveSwapQuoteReady = { expectation.fulfill() }

        fixture.presenter.didLoad(view: view)
        fixture.presenter.handleViewAppeared()
        fixture.presenter.didReceiveTotalIssuance(totalIssuance: BigUInt(1_000))
        fixture.presenter.didReceivePoolReserves(reserves: makeReserves())

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(fixture.interactor.estimatedFeeCalls.count, 1)
        XCTAssertEqual(fixture.interactor.estimatedFeeCalls.last?.baseAssetAmount, .zero)
        XCTAssertTrue(view.loadingStates.contains(true))
    }

    func testFullPercentageSelection_whenUserPoolExists_thenUsesPooledAmounts() {
        let fixture = makeFixture()
        let view = LiquidityPoolRemoveLiquidityViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.handleViewAppeared()
        fixture.presenter.didReceiveTotalIssuance(totalIssuance: BigUInt(1_000))
        fixture.presenter.didReceivePoolReserves(reserves: makeReserves())
        fixture.presenter.didReceiveUserPool(pool: makeAccountPool())
        fixture.presenter.selectFromAmountPercentage(1.0)

        XCTAssertEqual(fixture.interactor.estimatedFeeCalls.last?.baseAssetAmount, 4)
        XCTAssertEqual(fixture.interactor.estimatedFeeCalls.last?.targetAssetAmount, 5)
    }

    func testPreview_whenInputsAreValid_thenRoutesToConfirmation() {
        let fixture = makeFixture()
        let view = LiquidityPoolRemoveLiquidityViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.handleViewAppeared()
        fixture.presenter.didReceiveTotalIssuance(totalIssuance: BigUInt(1_000))
        fixture.presenter.didReceivePoolReserves(reserves: makeReserves())
        fixture.presenter.didReceiveUserPool(pool: makeAccountPool())
        fixture.presenter.didReceiveAccountInfo(result: .success(makeAccountInfo(free: 10_000)), for: fixture.baseChainAsset)
        fixture.presenter.didReceiveAccountInfo(result: .success(makeAccountInfo(free: 10_000)), for: fixture.targetChainAsset)
        fixture.presenter.didReceiveFee(BigUInt(1))
        fixture.presenter.updateFromAmount(2)
        fixture.presenter.updateToAmount(3)
        fixture.presenter.didTapPreviewButton()

        XCTAssertTrue(fixture.router.confirmationView === view)
        XCTAssertEqual(fixture.router.confirmationInfo?.baseAssetAmount, 1.5)
        XCTAssertEqual(fixture.router.confirmationInfo?.targetAssetAmount, 3)
        XCTAssertEqual(fixture.router.confirmationPair?.pairId, fixture.pair.pairId)
    }

    func testBackAndInfoActions_whenTapped_thenRouteThroughRouter() {
        let fixture = makeFixture()
        let view = LiquidityPoolRemoveLiquidityViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didTapBackButton()
        fixture.presenter.didTapApyInfo()
        fixture.presenter.didTapFeeInfo()

        XCTAssertTrue(fixture.router.dismissedView === view)
        XCTAssertEqual(fixture.router.presentedInfoCount, 2)
    }

    func testErrors_whenReceived_thenAreLogged() {
        let fixture = makeFixture()

        fixture.presenter.didReceiveTotalIssuanceError(error: TestError.expected)
        fixture.presenter.didReceiveUserPoolError(error: TestError.expected)
        fixture.presenter.didReceivePoolReservesError(error: TestError.expected)
        fixture.presenter.didReceiveFeeError(TestError.expected)

        XCTAssertEqual(fixture.logger.errorsCount, 4)
    }

    private func makeFixture() -> LiquidityPoolRemoveLiquidityFixture {
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
            removeInfo: nil,
            didSubmitTransactionClosure: { _ in }
        )

        return LiquidityPoolRemoveLiquidityFixture(
            presenter: presenter,
            interactor: interactor,
            router: router,
            logger: logger,
            chain: chain,
            pair: pair,
            baseChainAsset: chain.chainAssets.first { $0.asset.currencyId == pair.baseAssetId }!,
            targetChainAsset: chain.chainAssets.first { $0.asset.currencyId == pair.targetAssetId }!
        )
    }
}

private struct LiquidityPoolRemoveLiquidityFixture {
    let presenter: LiquidityPoolRemoveLiquidityPresenter
    let interactor: LiquidityPoolRemoveLiquidityInteractorInputSpy
    let router: LiquidityPoolRemoveLiquidityRouterSpy
    let logger: LoggerSpy
    let chain: ChainModel
    let pair: LiquidityPair
    let baseChainAsset: ChainAsset
    let targetChainAsset: ChainAsset
}

private final class LiquidityPoolRemoveLiquidityViewSpy: LiquidityPoolRemoveLiquidityViewInput {
    let controller = UIViewController()
    let isSetup = true

    private(set) var xorBalanceViewModel: BalanceViewModelProtocol?
    private(set) var fromViewModel: AssetBalanceViewModelProtocol?
    private(set) var toViewModel: AssetBalanceViewModelProtocol?
    private(set) var fromInputViewModel: IAmountInputViewModel?
    private(set) var toInputViewModel: IAmountInputViewModel?
    private(set) var swapQuoteReadyCount = 0
    private(set) var feeViewModel: BalanceViewModelProtocol?
    private(set) var loadingStates: [Bool] = []

    var onDidReceiveSwapQuoteReady: (() -> Void)?

    func didReceiveXorBalanceViewModel(balanceViewModel: BalanceViewModelProtocol?) {
        xorBalanceViewModel = balanceViewModel
    }

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

    func didReceiveSwapQuoteReady() {
        swapQuoteReadyCount += 1
        onDidReceiveSwapQuoteReady?()
    }

    func didReceiveNetworkFee(fee: BalanceViewModelProtocol?) {
        feeViewModel = fee
    }

    func setButtonLoadingState(isLoading: Bool) {
        loadingStates.append(isLoading)
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

private func makeReserves() -> PolkaswapPoolReservesInfo {
    PolkaswapPoolReservesInfo(
        reserves: PolkaswapPoolReserves(reserves: BigUInt(100), fee: BigUInt(200)),
        poolId: "xor-val"
    )
}

private func makeAccountPool() -> AccountPool {
    AccountPool(
        poolId: "xor-val",
        accountId: "account",
        chainId: "sora-chain",
        baseAssetId: "xor",
        targetAssetId: "val",
        baseAssetPooled: 4,
        targetAssetPooled: 5
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
