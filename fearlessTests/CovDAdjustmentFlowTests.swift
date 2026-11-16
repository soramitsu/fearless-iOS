import BigInt
import Foundation
import SoraFoundation
import SSFModels
import UIKit
import XCTest

@testable import fearless

/// Adjustment router that keeps sheet view models so their actions can be run, and finishes confirmations at once.
final class CovDAdjustmentAlertRouter: CovDRouterSpy, PolkaswapAdjustmentRouterInput {
    private(set) var sheets: [SheetAlertPresentableViewModel] = []
    private(set) var marketSelections: [[LiquiditySourceType]] = []
    private(set) var assetTags: [Int?] = []
    private(set) var confirmations: [PolkaswapPreviewParams] = []

    override func present(viewModel: SheetAlertPresentableViewModel, from view: ControllerBackedProtocol?) {
        sheets.append(viewModel)
        super.present(viewModel: viewModel, from: view)
    }

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
        assetTags.append(contextTag)
    }

    func showConfirmation(
        with params: PolkaswapPreviewParams,
        from _: ControllerBackedProtocol?,
        completeClosure: (() -> Void)?
    ) -> PolkaswapSwapConfirmationModuleInput? {
        confirmations.append(params)
        completeClosure?()
        return nil
    }

    func showDisclaimer(moduleOutput _: PolkaswapDisclaimerModuleOutput?, from _: ControllerBackedProtocol?) {}
}

final class CovDAdjustmentFlowTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        CovDFixtures.tearDown(window)
        window = nil
        super.tearDown()
    }

    private struct CovDFlow {
        let presenter: PolkaswapAdjustmentPresenter
        let controller: PolkaswapAdjustmentViewController
        let router: CovDAdjustmentAlertRouter
        let interactor: CovDAdjustmentInteractorSpy
        let xor: ChainAsset
        let token: ChainAsset
    }

    private func makeFlow(start: (ChainAsset, ChainAsset) -> ChainAsset?) throws -> CovDFlow {
        let chain = CovDSwapFixtures.chain(chainId: "covd-flow-\(UUID().uuidString)")
        let xor = try XCTUnwrap(chain.chainAssets.first { $0.asset.symbol == "XOR" })
        let token = try XCTUnwrap(chain.chainAssets.first { $0.asset.symbol == "TKN" })
        let wallet = CovDFixtures.wallet()
        let router = CovDAdjustmentAlertRouter()
        let interactor = CovDAdjustmentInteractorSpy()
        let validating = SendDataValidatingFactory(presentable: router)
        let presenter = PolkaswapAdjustmentPresenter(
            wallet: wallet,
            xorChainAsset: xor,
            swapChainAsset: start(xor, token),
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
        return CovDFlow(presenter: presenter, controller: controller, router: router, interactor: interactor, xor: xor, token: token)
    }

    private func spin(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: seconds))
    }

    /// Requests a quote for `amount` of the from-asset and answers it with `planks` of the to-asset.
    private func quote(_ flow: CovDFlow, amount: Decimal, planks: String) throws {
        flow.presenter.updateFromAmount(amount)
        spin(0.5)
        let request = try XCTUnwrap(flow.interactor.quoteRequests.last)
        flow.presenter.didReceiveSwapValues([SwapValues(dexId: 0, amount: planks, rewards: [])], params: request, errors: [])
    }

    func testMarketButtonWithoutAPairAsksForTheMissingAsset() throws {
        let empty = try makeFlow { _, _ in nil }
        empty.presenter.didTapMarketButton()
        let sheet = try XCTUnwrap(empty.router.sheets.last)
        XCTAssertEqual(sheet.actions.count, 1)
        XCTAssertNotNil(sheet.closeAction)
        sheet.actions.first?.handler?()
        XCTAssertEqual(empty.router.assetTags, [nil])

        empty.presenter.assetSelection(didCompleteWith: empty.token, contextTag: 1)
        empty.presenter.didTapMarketButton()
        empty.router.sheets.last?.actions.first?.handler?()
        XCTAssertEqual(empty.router.assetTags.last, 0)

        let fromXor = try makeFlow { xor, _ in xor }
        fromXor.presenter.didTapMarketButton()
        fromXor.router.sheets.last?.actions.first?.handler?()
        XCTAssertEqual(fromXor.router.assetTags, [1])
        XCTAssertTrue(fromXor.router.marketSelections.isEmpty)
    }

    func testDexInfoLimitsTheMarketsOfferedForThePair() throws {
        let flow = try makeFlow { xor, _ in xor }
        let settings = try XCTUnwrap(PolkaswapSettingsFactory.bundledSettings())
        flow.presenter.didReceiveSettings(settings: settings)
        flow.presenter.assetSelection(didCompleteWith: flow.token, contextTag: 1)
        let fromId = try XCTUnwrap(flow.xor.asset.currencyId)
        let toId = try XCTUnwrap(flow.token.asset.currencyId)

        flow.presenter.didReceiveDex(
            infos: [PolkaswapDexInfo(dexId: 0, pathIsAvailable: true, markets: ["XYKPool"])], fromAssetId: toId, toAssetId: fromId
        )
        flow.presenter.didTapMarketButton()
        XCTAssertEqual(flow.router.marketSelections.last, [.smart])

        flow.presenter.didReceiveDex(
            infos: [
                PolkaswapDexInfo(dexId: 1, pathIsAvailable: false, markets: ["MulticollateralBondingCurvePool"]),
                PolkaswapDexInfo(dexId: 0, pathIsAvailable: true, markets: ["XYKPool", "MulticollateralBondingCurvePool"])
            ],
            fromAssetId: fromId,
            toAssetId: toId
        )
        flow.presenter.didTapMarketButton()
        let markets = try XCTUnwrap(flow.router.marketSelections.last)
        XCTAssertTrue(markets.contains(.xyk), "\(markets)")
        XCTAssertTrue(markets.contains(.tbc), "\(markets)")
        XCTAssertTrue(flow.router.sheets.isEmpty)
    }

    func testFailedFirstQuoteClearsTheFormAndExplainsIt() throws {
        let flow = try makeFlow { xor, _ in xor }
        flow.presenter.didReceiveSettings(settings: try XCTUnwrap(PolkaswapSettingsFactory.bundledSettings()))
        flow.presenter.assetSelection(didCompleteWith: flow.token, contextTag: 1)
        flow.presenter.updateFromAmount(2)
        spin(0.5)
        let request = try XCTUnwrap(flow.interactor.quoteRequests.last)
        XCTAssertNil(flow.controller.presentedViewController)
        // The message goes through the router's default sheet presentation.
        flow.presenter.didReceiveSwapValues([], params: request, errors: [CovDTestError.offline])
        XCTAssertTrue(CovDFixtures.spin { flow.controller.presentedViewController is SheetAletViewController })
        let layout = flow.controller.rootView
        XCTAssertTrue(CovDFixtures.spin { layout.swapRouteView.valueTop.text?.isEmpty != false })
        flow.controller.presentedViewController?.dismiss(animated: false)
        XCTAssertTrue(CovDFixtures.spin { flow.controller.presentedViewController == nil })

        // A stale failure for an older request is ignored.
        flow.presenter.updateFromAmount(3)
        spin(0.5)
        flow.presenter.didReceiveSwapValues([], params: request, errors: [CovDTestError.offline])
        spin(0.3)
        XCTAssertNil(flow.controller.presentedViewController)
    }

    func testPreviewToXorWithoutFeeBalanceAsksForALargerAmount() throws {
        let flow = try makeFlow { _, token in token }
        flow.presenter.didReceiveSettings(settings: try XCTUnwrap(PolkaswapSettingsFactory.bundledSettings()))
        flow.presenter.assetSelection(didCompleteWith: flow.xor, contextTag: 1)
        flow.presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: CovDLiquidityFixtures.planks(5))), for: flow.token)
        flow.presenter.didReceiveAccountInfo(result: .success(nil), for: flow.xor)
        flow.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: CovDLiquidityFixtures.planks(Decimal(string: "0.007")!))))
        try quote(flow, amount: 1, planks: "1000000000000000")
        XCTAssertTrue(CovDFixtures.spin { flow.controller.rootView.swapRouteView.valueTop.text?.isEmpty == false })

        XCTAssertNil(flow.controller.presentedViewController)
        flow.presenter.didTapPreviewButton()
        guard MultiChainFeaturePolicy.current.polkaswapMutationsEnabled else {
            XCTAssertEqual(flow.router.infoTitles.last, "Polkaswap actions paused")
            return
        }
        XCTAssertTrue(CovDFixtures.spin { flow.controller.presentedViewController is SheetAletViewController })
        XCTAssertTrue(flow.router.confirmations.isEmpty)
    }

    func testConfirmedPreviewResetsTheQuoteWhenTheSwapCompletes() throws {
        let flow = try makeFlow { xor, _ in xor }
        flow.presenter.didReceiveSettings(settings: try XCTUnwrap(PolkaswapSettingsFactory.bundledSettings()))
        flow.presenter.assetSelection(didCompleteWith: flow.token, contextTag: 1)
        flow.presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: CovDLiquidityFixtures.planks(10))), for: flow.xor)
        flow.presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: CovDLiquidityFixtures.planks(1))), for: flow.token)
        flow.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: CovDLiquidityFixtures.planks(Decimal(string: "0.007")!))))
        try quote(flow, amount: 2, planks: "4000000000000000000")
        let layout = flow.controller.rootView
        XCTAssertTrue(CovDFixtures.spin { layout.swapRouteView.valueTop.text?.isEmpty == false })

        flow.presenter.didTapPreviewButton()
        guard MultiChainFeaturePolicy.current.polkaswapMutationsEnabled else {
            XCTAssertEqual(flow.router.infoTitles.last, "Polkaswap actions paused")
            return
        }
        let params = try XCTUnwrap(flow.router.confirmations.last)
        XCTAssertEqual(params.fromAmount, 2)
        XCTAssertEqual(params.toAmount, 4)
        XCTAssertEqual(params.swapToChainAsset.asset.symbol, "TKN")
        // The router finished the swap at once, so the quote is cleared and a second preview finds nothing to confirm.
        flow.presenter.didTapPreviewButton()
        XCTAssertEqual(flow.router.confirmations.count, 1)
    }
}
