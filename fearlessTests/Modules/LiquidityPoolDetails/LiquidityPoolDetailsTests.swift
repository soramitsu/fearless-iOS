import XCTest
import UIKit
import FearlessFoundation
import SSFModels
import SSFPools
import SSFStorageQueryKit
@testable import fearless

final class LiquidityPoolDetailsTests: XCTestCase {
    func testDidLoad_whenViewProvided_thenBootstrapsInteractor() {
        let fixture = makeFixture()
        let view = LiquidityPoolDetailsViewSpy()

        fixture.presenter.didLoad(view: view)

        XCTAssertTrue(fixture.interactor.output === fixture.presenter)
    }

    func testInteractorUpdates_whenPairArrives_thenBuildsAndBindsViewModel() {
        let fixture = makeFixture(input: .initial)
        let view = LiquidityPoolDetailsViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didReceiveLiquidityPair(liquidityPair: fixture.pair)

        XCTAssertEqual(view.viewModel?.pairTitleLabelText, "XOR-VAL")
        XCTAssertEqual(fixture.viewModelFactory.lastPair?.pairId, fixture.pair.pairId)
        XCTAssertNil(fixture.viewModelFactory.lastInput?.liquidityPair)
    }

    func testSupplyAndRemove_whenPairIsAvailable_thenRoutesFlows() {
        let fixture = makeFixture()
        let view = LiquidityPoolDetailsViewSpy()
        var submittedHash: String?

        let presenter = LiquidityPoolDetailsPresenter(
            interactor: fixture.interactor,
            router: fixture.router,
            localizationManager: LocalizationManager.shared,
            assetIdPair: AssetIdPair(
                baseAssetIdCode: fixture.pair.baseAssetId,
                targetAssetIdCode: fixture.pair.targetAssetId
            ),
            logger: LoggerSpy(),
            viewModelFactory: fixture.viewModelFactory,
            chain: fixture.chain,
            wallet: fixture.wallet,
            input: .availablePool(
                liquidityPair: fixture.pair,
                reserves: nil,
                apyInfo: nil,
                availablePairs: [fixture.pair]
            ),
            didSubmitTransactionClosure: { submittedHash = $0 }
        )

        presenter.didLoad(view: view)
        presenter.supplyButtonClicked()
        presenter.removeButtonClicked()
        fixture.router.supplySubmitClosure?("0xsupply")

        XCTAssertTrue(fixture.router.supplyView === view)
        XCTAssertTrue(fixture.router.removeView === view)
        XCTAssertEqual(fixture.router.supplyPair?.pairId, fixture.pair.pairId)
        XCTAssertEqual(fixture.router.removePair?.pairId, fixture.pair.pairId)
        XCTAssertEqual(fixture.router.availablePairs?.map(\.pairId), [fixture.pair.pairId])
        XCTAssertEqual(submittedHash, "0xsupply")
    }

    func testNavigationAndInfo_whenTapped_thenRoutesThroughRouter() {
        let fixture = makeFixture()
        let view = LiquidityPoolDetailsViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.backButtonClicked()
        fixture.presenter.didTapApyInfo()

        XCTAssertTrue(fixture.router.dismissedView === view)
        XCTAssertEqual(fixture.router.presentedInfoCount, 1)
    }

    func testErrors_whenReceived_thenAreLogged() {
        let fixture = makeFixture()

        fixture.presenter.didReceiveLiquidityPairError(error: TestError.expected)
        fixture.presenter.didReceiveUserPoolError(error: TestError.expected)
        fixture.presenter.didReceivePoolReservesError(error: TestError.expected)
        fixture.presenter.didReceivePoolApyError(error: TestError.expected)

        XCTAssertEqual(fixture.logger.errorsCount, 4)
    }

    private func makeFixture(
        input: LiquidityPoolDetailsInput? = nil
    ) -> LiquidityPoolDetailsFixture {
        let interactor = LiquidityPoolDetailsInteractorInputSpy()
        let router = LiquidityPoolDetailsRouterSpy()
        let viewModelFactory = LiquidityPoolDetailsViewModelFactorySpy()
        let chain = makeLiquidityChain()
        let wallet = AccountGenerator.generateMetaAccount().replacingName("Wallet")
        let pair = makeLiquidityPair()
        let logger = LoggerSpy()
        let presenter = LiquidityPoolDetailsPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            assetIdPair: AssetIdPair(baseAssetIdCode: pair.baseAssetId, targetAssetIdCode: pair.targetAssetId),
            logger: logger,
            viewModelFactory: viewModelFactory,
            chain: chain,
            wallet: wallet,
            input: input ?? .availablePool(
                liquidityPair: pair,
                reserves: nil,
                apyInfo: nil,
                availablePairs: [pair]
            ),
            didSubmitTransactionClosure: { _ in }
        )

        return LiquidityPoolDetailsFixture(
            presenter: presenter,
            interactor: interactor,
            router: router,
            viewModelFactory: viewModelFactory,
            logger: logger,
            chain: chain,
            wallet: wallet,
            pair: pair
        )
    }
}

private struct LiquidityPoolDetailsFixture {
    let presenter: LiquidityPoolDetailsPresenter
    let interactor: LiquidityPoolDetailsInteractorInputSpy
    let router: LiquidityPoolDetailsRouterSpy
    let viewModelFactory: LiquidityPoolDetailsViewModelFactorySpy
    let logger: LoggerSpy
    let chain: ChainModel
    let wallet: MetaAccountModel
    let pair: LiquidityPair
}

private final class LiquidityPoolDetailsViewSpy: LiquidityPoolDetailsViewInput {
    let controller = UIViewController()
    let isSetup = true

    private(set) var viewModel: LiquidityPoolDetailsViewModel?

    func bind(viewModel: LiquidityPoolDetailsViewModel?) {
        self.viewModel = viewModel
    }
}

private final class LiquidityPoolDetailsInteractorInputSpy: LiquidityPoolDetailsInteractorInput {
    private(set) weak var output: LiquidityPoolDetailsInteractorOutput?

    func setup(with output: LiquidityPoolDetailsInteractorOutput) {
        self.output = output
    }
}

private final class LiquidityPoolDetailsRouterSpy: LiquidityPoolDetailsRouterInput {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) weak var supplyView: ControllerBackedProtocol?
    private(set) weak var removeView: ControllerBackedProtocol?
    private(set) var supplyPair: LiquidityPair?
    private(set) var removePair: LiquidityPair?
    private(set) var availablePairs: [LiquidityPair]?
    private(set) var presentedInfoCount = 0
    var supplySubmitClosure: ((String) -> Void)?

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func showSupplyFlow(
        liquidityPair: LiquidityPair,
        chain _: ChainModel,
        wallet _: MetaAccountModel,
        availablePairs: [LiquidityPair]?,
        didSubmitTransactionClosure: @escaping (String) -> Void,
        from view: ControllerBackedProtocol?
    ) {
        supplyPair = liquidityPair
        self.availablePairs = availablePairs
        supplySubmitClosure = didSubmitTransactionClosure
        supplyView = view
    }

    func showRemoveFlow(
        liquidityPair: LiquidityPair,
        chain _: ChainModel,
        wallet _: MetaAccountModel,
        didSubmitTransactionClosure _: @escaping (String) -> Void,
        from view: ControllerBackedProtocol?
    ) {
        removePair = liquidityPair
        removeView = view
    }

    func present(
        viewModel _: SheetAlertPresentableViewModel,
        from _: ControllerBackedProtocol?
    ) {}

    func present(
        message _: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {}

    func presentInfo(
        message _: String?,
        title _: String,
        from _: ControllerBackedProtocol?
    ) {
        presentedInfoCount += 1
    }

    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        true
    }
}

private final class LiquidityPoolDetailsViewModelFactorySpy: LiquidityPoolDetailsViewModelFactory {
    private(set) var lastPair: LiquidityPair?
    private(set) var lastInput: LiquidityPoolDetailsInput?

    func buildViewModel(
        liquidityPair: LiquidityPair,
        reserves _: CachedStorageResponse<PolkaswapPoolReservesInfo>?,
        apyInfo _: PoolApyInfo?,
        chain _: ChainModel,
        locale _: Locale,
        wallet _: MetaAccountModel,
        accountPoolInfo _: AccountPool?,
        input: LiquidityPoolDetailsInput
    ) -> LiquidityPoolDetailsViewModel? {
        lastPair = liquidityPair
        lastInput = input

        return LiquidityPoolDetailsViewModel(
            pairTitleLabelText: "XOR-VAL",
            baseAssetName: "XOR",
            targetAssetName: "VAL",
            reservesViewModel: nil,
            apyViewModel: nil,
            rewardTokenLabelText: "PSWAP",
            baseAssetViewModel: nil,
            targetAssetViewModel: nil,
            tokenPairIconsViewModel: nil,
            userPoolFieldsHidden: true,
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
