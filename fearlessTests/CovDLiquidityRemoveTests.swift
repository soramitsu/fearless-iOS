import BigInt
import Foundation
import SoraFoundation
import SSFModels
import SSFPolkaswap
import SSFPools
import UIKit
import XCTest

@testable import fearless

final class CovDLiquidityRemoveTests: XCTestCase {
    typealias CovDF = CovDLiquidityFixtures
    private var window: UIWindow?

    override func tearDown() {
        CovDFixtures.tearDown(window)
        window = nil
        super.tearDown()
    }

    private func makePresenter(
        chain: ChainModel,
        router: CovDRemoveRouterSpy,
        interactor: CovDRemoveInteractorSpy,
        removeInfo: RemoveLiquidityInfo?,
        hashes: @escaping (String) -> Void = { _ in }
    ) -> (LiquidityPoolRemoveLiquidityPresenter, SendDataValidatingFactory) {
        let validating = SendDataValidatingFactory(presentable: router)
        let presenter = LiquidityPoolRemoveLiquidityPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            wallet: CovDFixtures.wallet(),
            logger: Logger.shared,
            chain: chain,
            liquidityPair: CovDF.pair(chain),
            dataValidatingFactory: validating,
            confirmViewModelFactory: LiquidityPoolSupplyConfirmViewModelFactoryDefault(),
            removeInfo: removeInfo,
            didSubmitTransactionClosure: hashes,
            submissionAuthorizer: CovDSubmissionAuthorizerStub()
        )
        return (presenter, validating)
    }

    func testRemoveScreenCalculatesAmountsFromReservesAndPooledBalances() throws {
        let chain = CovDF.chain()
        let router = CovDRemoveRouterSpy()
        let interactor = CovDRemoveInteractorSpy()
        let (presenter, validating) = makePresenter(chain: chain, router: router, interactor: interactor, removeInfo: nil)
        let controller = LiquidityPoolRemoveLiquidityViewController(output: presenter, localizationManager: LocalizationManager.shared)
        validating.view = controller
        window = try CovDFixtures.host(UINavigationController(rootViewController: controller))
        presenter.handleViewAppeared()
        let layout = controller.rootView
        XCTAssertEqual(interactor.setupCount, 1)
        XCTAssertTrue(interactor.feeRequests.isEmpty)

        presenter.didReceiveTotalIssuance(totalIssuance: CovDF.planks(1000))
        XCTAssertTrue(interactor.feeRequests.isEmpty)
        presenter.didReceivePoolReserves(reserves: nil)
        presenter.didReceivePoolReserves(reserves: CovDLiquidityReserves.make(
            poolId: "\(CovDF.xor)-\(CovDF.val)", reserves: CovDF.planks(100), fee: CovDF.planks(200)
        ))
        XCTAssertEqual(interactor.feeRequests.last?.baseAssetReserves, 100)
        XCTAssertEqual(interactor.feeRequests.last?.totalIssuances, 1000)
        XCTAssertEqual(interactor.feeRequests.last?.baseAssetAmount, .zero)
        XCTAssertTrue(CovDFixtures.spin { layout.swapFromInputView.textField.isUserInteractionEnabled })

        presenter.didReceiveUserPool(pool: CovDF.accountPool(chain))
        presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: CovDF.planks(10))), for: CovDF.chainAsset(chain, CovDF.xor))
        presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: CovDF.planks(20))), for: CovDF.chainAsset(chain, CovDF.val))
        presenter.didReceiveAccountInfo(result: .failure(CovDTestError.offline), for: CovDF.chainAsset(chain, CovDF.val))
        XCTAssertTrue(CovDFixtures.spin { layout.balanceView.valueTop.text?.contains("10") == true })

        presenter.selectFromAmountPercentage(0.5)
        XCTAssertEqual(interactor.feeRequests.last?.baseAssetAmount, 5)
        XCTAssertEqual(interactor.feeRequests.last?.targetAssetAmount, 10)
        presenter.selectFromAmountPercentage(1)
        XCTAssertEqual(interactor.feeRequests.last?.baseAssetAmount, 4)
        XCTAssertEqual(interactor.feeRequests.last?.targetAssetAmount, 8)

        presenter.didReceiveFee(CovDF.planks(Decimal(string: "0.01")!))
        XCTAssertTrue(CovDFixtures.spin { layout.networkFeeView.valueTop.text?.contains("0.01") == true })
        presenter.didTapPreviewButton()
        XCTAssertEqual(router.confirmations.count, 1)
        XCTAssertEqual(router.confirmations.first?.baseAssetAmount, 4)
        XCTAssertEqual(router.confirmations.first?.targetAssetAmount, 8)

        presenter.selectToAmountPercentage(0.25)
        XCTAssertEqual(interactor.feeRequests.last?.targetAssetAmount, 5)
        XCTAssertEqual(interactor.feeRequests.last?.baseAssetAmount, Decimal(string: "2.5"))
        presenter.updateFromAmount(2)
        XCTAssertEqual(interactor.feeRequests.last?.targetAssetAmount, 4)
        presenter.selectToAmountPercentage(1)
        XCTAssertEqual(interactor.feeRequests.last?.targetAssetAmount, 8)
        presenter.updateToAmount(16)
        XCTAssertEqual(interactor.feeRequests.last?.baseAssetAmount, 8)
        presenter.didTapPreviewButton()
        XCTAssertEqual(router.confirmations.count, 1)
        XCTAssertTrue(CovDFixtures.spin { controller.presentedViewController is SheetAletViewController })
    }

    func testRemoveScreenActionsAndSubmissionCallbacks() throws {
        let chain = CovDF.chain()
        let router = CovDRemoveRouterSpy()
        let interactor = CovDRemoveInteractorSpy()
        var hashes: [String] = []
        let (presenter, validating) = makePresenter(
            chain: chain, router: router, interactor: interactor, removeInfo: nil, hashes: { hashes.append($0) }
        )
        let controller = LiquidityPoolRemoveLiquidityViewController(output: presenter, localizationManager: LocalizationManager.shared)
        validating.view = controller
        window = try CovDFixtures.host(controller)
        presenter.didTapApyInfo()
        presenter.didTapFeeInfo()
        XCTAssertEqual(router.infoTitles.count, 2)
        controller.rootView.backButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(router.dismissCount, 1)
        presenter.didTapPreviewButton()
        XCTAssertTrue(router.confirmations.isEmpty)

        presenter.didReceiveSubmitError(error: CovDTestError.offline)
        XCTAssertEqual(router.errors, ["CovD offline"])
        presenter.didReceiveTransactionHash("0xremoved")
        XCTAssertEqual(hashes, ["0xremoved"])
        XCTAssertEqual(router.completions, ["0xremoved"])
        presenter.didReceiveTotalIssuanceError(error: CovDTestError.offline)
        presenter.didReceiveFeeError(CovDTestError.offline)
        presenter.didReceiveUserPoolError(error: CovDTestError.offline)
        presenter.didReceivePoolReservesError(error: CovDTestError.offline)
        presenter.applyLocalization()
        controller.applyLocalization()
        XCTAssertEqual(router.errors.count, 1)
    }

    func testConfirmScreenShowsAmountsAndGuardsSubmission() throws {
        let chain = CovDF.chain()
        let router = CovDRemoveRouterSpy()
        let interactor = CovDRemoveInteractorSpy()
        let info = RemoveLiquidityInfo(
            dexId: "0",
            baseAsset: PooledAssetInfo(id: CovDF.xor, precision: 18),
            targetAsset: PooledAssetInfo(id: CovDF.val, precision: 18),
            baseAssetAmount: 4,
            targetAssetAmount: 8,
            baseAssetReserves: 100,
            totalIssuances: 1000,
            slippage: Decimal(string: "0.5")!
        )
        let (presenter, _) = makePresenter(chain: chain, router: router, interactor: interactor, removeInfo: info)
        let controller = LiquidityPoolRemoveLiquidityConfirmViewController(output: presenter, localizationManager: LocalizationManager.shared)
        window = try CovDFixtures.host(UINavigationController(rootViewController: controller))
        presenter.handleViewAppeared()
        let layout = controller.rootView
        XCTAssertEqual(interactor.setupCount, 1)
        XCTAssertTrue(CovDFixtures.spin {
            let text = layout.amountsLabel.attributedText?.string ?? ""
            return text.contains("XOR") && text.contains("VAL")
        })
        XCTAssertEqual(interactor.feeRequests.last?.totalIssuances, 1000)
        XCTAssertEqual(interactor.feeRequests.last?.baseAssetReserves, 100)

        presenter.didReceiveFee(CovDF.planks(Decimal(string: "0.02")!))
        XCTAssertTrue(CovDFixtures.spin { layout.networkFeeView.valueTop.text?.contains("0.02") == true })

        layout.confirmButton.sendActions(for: .touchUpInside)
        let blocked = ["Liquidity actions paused", "Liquidity actions unavailable"]
        if let title = router.infoTitles.last {
            XCTAssertTrue(blocked.contains(title), title)
            XCTAssertTrue(interactor.submissions.isEmpty)
        } else {
            XCTAssertEqual(interactor.submissions.count, 1)
            XCTAssertEqual(interactor.submissions.first?.baseAssetAmount, 4)
        }
        presenter.didTapFeeInfo()
        layout.backButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(router.dismissCount, 1)
    }

    func testConfirmViewModelFactoryRequiresBothAssets() {
        let chain = CovDF.chain()
        let factory = LiquidityPoolSupplyConfirmViewModelFactoryDefault()
        let viewModel = factory.buildViewModel(
            baseAssetAmount: Decimal(string: "1.5")!,
            targetAssetAmount: 3,
            liquidityPair: CovDF.pair(chain),
            chain: chain,
            locale: Locale(identifier: "en_US")
        )
        let text = viewModel?.amountsText.string ?? ""
        XCTAssertTrue(text.hasPrefix("1.500 XOR"), text)
        XCTAssertTrue(text.contains("3.000 VAL"), text)
        XCTAssertNotNil(viewModel?.doubleImageViewViewModel)
        XCTAssertNil(factory.buildViewModel(
            baseAssetAmount: 1, targetAssetAmount: 1, liquidityPair: CovDF.pair(chain),
            chain: CovDFixtures.soraChain(assets: []), locale: Locale(identifier: "en_US")
        ))
    }
}
