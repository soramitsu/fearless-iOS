import BigInt
import Foundation
import SoraFoundation
import SSFModels
import UIKit
import XCTest

@testable import fearless

final class CovDAdjustmentRouterSpy: CovDRouterSpy, PolkaswapAdjustmentRouterInput {
    private(set) var marketSelections: [[LiquiditySourceType]] = []
    private(set) var assetSelections: [Int?] = []
    private(set) var confirmations: [PolkaswapPreviewParams] = []
    private(set) var disclaimers = 0

    func showSelectMarket(
        from _: ControllerBackedProtocol?,
        markets: [LiquiditySourceType],
        selectedMarket _: LiquiditySourceType,
        slippadgeTolerance _: Float,
        moduleOutput _: PolkaswapTransaktionSettingsModuleOutput
    ) {
        marketSelections.append(markets)
    }

    func showSelectAsset(
        from _: ControllerBackedProtocol?,
        wallet _: MetaAccountModel,
        chainAssets _: [ChainAsset]?,
        selectedAssetId _: AssetModel.Id?,
        contextTag: Int?,
        output _: SelectAssetModuleOutput
    ) {
        assetSelections.append(contextTag)
    }

    func showConfirmation(
        with params: PolkaswapPreviewParams,
        from _: ControllerBackedProtocol?,
        completeClosure _: (() -> Void)?
    ) -> PolkaswapSwapConfirmationModuleInput? {
        confirmations.append(params)
        return nil
    }

    func showDisclaimer(moduleOutput _: PolkaswapDisclaimerModuleOutput?, from _: ControllerBackedProtocol?) {
        disclaimers += 1
    }
}

final class CovDAdjustmentInteractorSpy: PolkaswapAdjustmentInteractorInput {
    private(set) weak var output: PolkaswapAdjustmentInteractorOutput?
    private(set) var pairs: [(String?, String?)] = []
    private(set) var quoteRequests: [PolkaswapQuoteParams] = []
    private(set) var feeRequests: [SwapVariant] = []
    private(set) var blockSubscriptions = 0
    private(set) var disclaimerChecks = 0

    func setup(with output: PolkaswapAdjustmentInteractorOutput) { self.output = output }

    func didReceive(_ fromChainAsset: ChainAsset?, _ toChainAsset: ChainAsset?) {
        pairs.append((fromChainAsset?.asset.symbol, toChainAsset?.asset.symbol))
    }

    func fetchQuotes(with params: PolkaswapQuoteParams) { quoteRequests.append(params) }
    func subscribeOnBlocks() { blockSubscriptions += 1 }

    func estimateFee(
        dexId _: String,
        fromAssetId _: String,
        toAssetId _: String,
        swapVariant: SwapVariant,
        swapAmount _: SwapAmount,
        filter _: PolkaswapLiquidityFilterMode,
        liquiditySourceType _: LiquiditySourceType
    ) {
        feeRequests.append(swapVariant)
    }

    func fetchDisclaimerVisible() { disclaimerChecks += 1 }
}

final class CovDPolkaswapAdjustmentTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        CovDFixtures.tearDown(window)
        window = nil
        super.tearDown()
    }

    private struct CovDModule {
        let presenter: PolkaswapAdjustmentPresenter
        let controller: PolkaswapAdjustmentViewController
        let router: CovDAdjustmentRouterSpy
        let interactor: CovDAdjustmentInteractorSpy
        let xor: ChainAsset
        let token: ChainAsset
    }

    private func makeModule() throws -> CovDModule {
        let chain = CovDFixtures.soraChain(assets: [
            AssetModel(
                id: "xor", name: "SORA", symbol: "XOR", precision: 18, currencyId: PolkamarktConstants.feeAssetId,
                isUtility: true, isNative: true, type: .soraAsset
            ),
            AssetModel(
                id: "tkn", name: "Token", symbol: "TKN", precision: 18, currencyId: "0x" + String(repeating: "01", count: 32),
                isUtility: false, isNative: false, type: .soraAsset
            )
        ])
        let xor = try XCTUnwrap(chain.chainAssets.first { $0.asset.symbol == "XOR" })
        let token = try XCTUnwrap(chain.chainAssets.first { $0.asset.symbol == "TKN" })
        let wallet = CovDFixtures.wallet()
        let router = CovDAdjustmentRouterSpy()
        let interactor = CovDAdjustmentInteractorSpy()
        let validating = SendDataValidatingFactory(presentable: router)
        let presenter = PolkaswapAdjustmentPresenter(
            wallet: wallet,
            xorChainAsset: xor,
            swapChainAsset: xor,
            viewModelFactory: PolkaswapAdjustmentViewModelFactory(
                wallet: wallet, xorChainAsset: xor, assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
            ),
            dataValidatingFactory: validating,
            interactor: interactor,
            router: router,
            swapVariant: .desiredInput,
            localizationManager: LocalizationManager.shared
        )
        let controller = PolkaswapAdjustmentViewController(
            output: presenter, bannersViewController: UIViewController(), localizationManager: LocalizationManager.shared
        )
        validating.view = controller
        window = try CovDFixtures.host(controller)
        return CovDModule(presenter: presenter, controller: controller, router: router, interactor: interactor, xor: xor, token: token)
    }

    private func spin(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: seconds))
    }

    func testQuoteFlowFillsAmountsDetailsAndFee() throws {
        let module = try makeModule()
        let presenter = module.presenter
        let layout = module.controller.rootView
        XCTAssertTrue(module.interactor.output === presenter)
        XCTAssertEqual(module.interactor.pairs.first?.0, "XOR")
        XCTAssertNil(module.interactor.pairs.first?.1)

        presenter.didReceiveSettings(settings: try XCTUnwrap(PolkaswapSettingsFactory.bundledSettings()))
        presenter.assetSelection(didCompleteWith: module.token, contextTag: 1)
        presenter.assetSelection(didCompleteWith: nil, contextTag: 1)
        presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: CovDLiquidityFixtures.planks(10))), for: module.xor)
        presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: CovDLiquidityFixtures.planks(3))), for: module.token)
        presenter.didReceiveAccountInfo(result: .failure(CovDTestError.offline), for: module.token)
        XCTAssertEqual(module.router.errors, ["CovD offline"])
        presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: CovDLiquidityFixtures.planks(Decimal(string: "0.007")!))))
        presenter.didReceiveFee(result: .failure(CovDTestError.offline))
        XCTAssertTrue(CovDFixtures.spin { layout.networkFeeView.valueTop.text?.contains("0.007") == true })

        presenter.updateFromAmount(2)
        spin(0.5)
        let request = try XCTUnwrap(module.interactor.quoteRequests.last)
        presenter.didReceiveSwapValues(
            [SwapValues(dexId: 0, amount: "4000000000000000000", rewards: [])],
            params: request,
            errors: []
        )
        XCTAssertTrue(CovDFixtures.spin { layout.swapRouteView.valueTop.text?.isEmpty == false })
        XCTAssertNotNil(layout.minMaxReceivedView.valueTop.text)
        XCTAssertNotNil(layout.fromPerToPriceView.valueTop.text)

        presenter.didTapInput(variant: .desiredOutput)
        presenter.didTapMinReceiveInfo()
        presenter.didTapInput(variant: .desiredInput)
        presenter.didTapMinReceiveInfo()
        presenter.didTapNetworkFeeInfo()
        XCTAssertEqual(module.router.infoTitles.count, 3)
        XCTAssertEqual(Set(module.router.infoTitles).count, 3)

        presenter.didTapPreviewButton()
        if MultiChainFeaturePolicy.current.polkaswapMutationsEnabled {
            XCTAssertEqual(module.router.confirmations.count, 1)
        } else {
            XCTAssertEqual(module.router.infoTitles.last, "Polkaswap actions paused")
            XCTAssertTrue(module.router.confirmations.isEmpty)
        }

        presenter.didReceive(market: .smart, slippadgeTolerance: 1.5)
        presenter.didReceive(market: .xyk, slippadgeTolerance: 1.5)
        presenter.selectToAmountPercentage(0.5)
        presenter.updateToAmount(1)
        presenter.selectFromAmountPercentage(0.25)
        spin(0.5)
        XCTAssertGreaterThan(module.interactor.quoteRequests.count, 1)
        presenter.updateQuotes()
        let requestsBeforeSwitch = module.interactor.quoteRequests.count
        presenter.didTapSwitchInputsButton()
        spin(0.5)
        XCTAssertGreaterThan(module.interactor.quoteRequests.count, requestsBeforeSwitch)
        XCTAssertEqual(module.interactor.quoteRequests.last?.fromAssetId, "0x" + String(repeating: "01", count: 32))
    }

    func testNavigationSelectionDisclaimerAndBanners() throws {
        let module = try makeModule()
        let presenter = module.presenter
        let layout = module.controller.rootView

        presenter.didReceiveDisclaimer(isRead: false)
        XCTAssertEqual(module.router.disclaimers, 1)
        presenter.viewDidAppear()
        XCTAssertGreaterThanOrEqual(module.interactor.disclaimerChecks, 1)
        presenter.didReceiveDisclaimer(isRead: false)
        presenter.didReceiveDisclaimer(isRead: true)
        XCTAssertEqual(module.router.disclaimers, 1)

        presenter.didTapSelectFromAsset()
        presenter.didTapSelectToAsset()
        XCTAssertEqual(module.router.assetSelections, [0, 1])
        presenter.didTapMarketButton()
        XCTAssertEqual(module.router.alertTitles.count + module.router.marketSelections.count, 1)

        layout.backButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(module.router.dismissCount, 1)
        presenter.didTapCloseBanners()
        presenter.reloadBannersView()
        XCTAssertTrue(CovDFixtures.spin { layout.bannersViewContainer.superview == nil })
        presenter.didReceive(error: CovDTestError.offline)
        presenter.toggleSwapDirection()
        presenter.applyLocalization()
        module.controller.applyLocalization()
        module.controller.didUpdating()
        module.controller.didReceive(variant: .desiredOutput)
        module.controller.setButtonLoadingState(isLoading: true)
        XCTAssertFalse(layout.previewButton.isEnabled)
    }
}
