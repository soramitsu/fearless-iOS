import BigInt
import Foundation
import SoraFoundation
import SSFModels
import SSFPolkaswap
import SSFPools
import UIKit
import XCTest

@testable import fearless

final class CovDLiquiditySupplyTests: XCTestCase {
    typealias CovDF = CovDLiquidityFixtures
    private var window: UIWindow?

    override func tearDown() {
        CovDFixtures.tearDown(window)
        window = nil
        super.tearDown()
    }

    private struct CovDModule {
        let chain: ChainModel
        let presenter: LiquidityPoolSupplyPresenter
        let controller: LiquidityPoolSupplyViewController
        let router: CovDSupplyRouterSpy
        let interactor: CovDSupplyInteractorSpy
    }

    private func makeModule(availablePairs: [LiquidityPair]? = nil) throws -> CovDModule {
        let chain = CovDF.chain()
        let router = CovDSupplyRouterSpy()
        let interactor = CovDSupplyInteractorSpy()
        let validating = SendDataValidatingFactory(presentable: router)
        let presenter = LiquidityPoolSupplyPresenter(
            interactor: interactor,
            router: router,
            liquidityPair: CovDF.pair(chain),
            localizationManager: LocalizationManager.shared,
            chain: chain,
            logger: Logger.shared,
            wallet: CovDFixtures.wallet(),
            dataValidatingFactory: validating,
            viewModelFactory: LiquidityPoolSupplyViewModelFactoryDefault(),
            availablePairs: availablePairs,
            didSubmitTransactionClosure: { _ in }
        )
        let controller = LiquidityPoolSupplyViewController(output: presenter, localizationManager: LocalizationManager.shared)
        validating.view = controller
        window = try CovDFixtures.host(UINavigationController(rootViewController: controller))
        if interactor.feeRequests.isEmpty {
            presenter.handleViewAppeared()
        }
        return CovDModule(chain: chain, presenter: presenter, controller: controller, router: router, interactor: interactor)
    }

    func testSupplyScreenLoadsTermsAndRequestsTheFirstFee() throws {
        let module = try makeModule()
        let layout = module.controller.rootView
        XCTAssertTrue(module.interactor.output === module.presenter)
        XCTAssertEqual(module.interactor.fetchPoolsCount, 1)
        XCTAssertEqual(module.interactor.feeRequests.last?.baseAsset.id, CovDF.xor)
        XCTAssertEqual(module.interactor.feeRequests.last?.targetAsset.id, CovDF.val)
        XCTAssertEqual(module.interactor.feeRequests.last?.baseAssetAmount, .zero)
        XCTAssertEqual(module.interactor.feeRequests.last?.slippage, Decimal(string: "0.5"))
        XCTAssertTrue(CovDFixtures.spin { layout.rewardTokenView.valueTop.text == "PSWAP" })
        XCTAssertEqual(layout.slippageView.valueTop.text, "0.50%")
        XCTAssertNil(layout.apyView.valueTop.text)
        XCTAssertFalse(layout.titleLabel.text?.isEmpty ?? true)

        module.presenter.didReceivePoolAPY(apyInfo: PoolApyInfo(poolId: "p", apy: Decimal(string: "12.5")))
        let apyText = NumberFormatter.percentAPY.stringFromDecimal(Decimal(string: "12.5")!)
        CovDFixtures.spin(timeout: 1) { layout.apyView.valueTop.text == apyText }
        XCTAssertEqual(layout.apyView.valueTop.text, apyText)
        XCTAssertFalse(layout.previewButton.isEnabled)

        module.controller.didReceiveSwapQuoteReady()
        XCTAssertTrue(layout.swapFromInputView.textField.isUserInteractionEnabled)
        XCTAssertTrue(layout.swapToInputView.textField.isUserInteractionEnabled)
    }

    func testAmountsFollowPoolReservesAndPreviewOpensConfirmation() throws {
        let module = try makeModule(availablePairs: [])
        let presenter = module.presenter
        let layout = module.controller.rootView
        XCTAssertEqual(module.interactor.fetchPoolsCount, 0)
        let xor = CovDF.chainAsset(module.chain, CovDF.xor)
        let val = CovDF.chainAsset(module.chain, CovDF.val)

        presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: CovDF.planks(10))), for: xor)
        presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: CovDF.planks(20))), for: val)
        presenter.didReceiveAccountInfo(result: .failure(CovDTestError.offline), for: val)
        presenter.didReceivePricesData(result: .success([]))
        presenter.didReceivePricesData(result: .failure(CovDTestError.offline))
        presenter.didReceivePoolReserves(reserves: CovDLiquidityReserves.make(
            poolId: "\(CovDF.xor)-\(CovDF.val)", reserves: CovDF.planks(100), fee: CovDF.planks(200)
        ))
        presenter.updateFromAmount(1)
        XCTAssertEqual(module.interactor.feeRequests.last?.baseAssetAmount, 1)
        XCTAssertEqual(module.interactor.feeRequests.last?.targetAssetAmount, 2)
        XCTAssertTrue(CovDFixtures.spin { layout.swapToInputView.inputFieldText == "2" })

        presenter.didReceiveFee(CovDF.planks(Decimal(string: "0.01")!))
        XCTAssertTrue(CovDFixtures.spin { layout.networkFeeView.valueTop.text?.contains("0.01") == true })

        presenter.didTapPreviewButton()
        XCTAssertEqual(module.router.confirmations.count, 1)
        XCTAssertEqual(module.router.confirmations.first?.baseAssetAmount, 1)
        XCTAssertEqual(module.router.confirmations.first?.targetAssetAmount, 2)
        XCTAssertEqual(module.router.confirmations.first?.availablePools?.count, 0)

        presenter.selectToAmountPercentage(0.5)
        XCTAssertEqual(module.interactor.feeRequests.last?.targetAssetAmount, 10)
        XCTAssertEqual(module.interactor.feeRequests.last?.baseAssetAmount, 5)
        presenter.updateToAmount(4)
        XCTAssertEqual(module.interactor.feeRequests.last?.baseAssetAmount, 2)

        presenter.selectFromAmountPercentage(1)
        XCTAssertEqual(module.interactor.feeRequests.last?.baseAssetAmount, 10)
        presenter.didTapPreviewButton()
        XCTAssertEqual(module.router.confirmations.count, 1)
        XCTAssertTrue(CovDFixtures.spin { module.controller.presentedViewController is SheetAletViewController })
    }

    func testInfoButtonsBackAndErrorCallbacks() throws {
        let module = try makeModule()
        let presenter = module.presenter
        presenter.didTapApyInfo()
        presenter.didTapFeeInfo()
        XCTAssertEqual(module.router.infoTitles.count, 2)
        XCTAssertEqual(Set(module.router.infoTitles).count, 2)
        module.controller.rootView.backButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(module.router.dismissCount, 1)
        module.controller.rootView.previewButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(module.router.confirmations.count, 0)
        XCTAssertTrue(CovDFixtures.spin { module.controller.presentedViewController is SheetAletViewController })

        presenter.didReceiveFeeError(CovDTestError.offline)
        presenter.didReceivePoolApyError(error: CovDTestError.offline)
        presenter.didReceiveLiquidityPairsError(error: CovDTestError.offline)
        presenter.didReceivePoolReservesError(error: CovDTestError.offline)
        presenter.didReceiveLiquidityPairs(pairs: [CovDF.pair(module.chain)])
        presenter.didReceivePoolReserves(reserves: nil)
        presenter.applyLocalization()
        module.controller.applyLocalization()
        XCTAssertEqual(module.router.errors.count, 0)
        XCTAssertEqual(module.interactor.fetchPoolsCount, 1)
    }

    func testViewModelFactoryFormatsSlippageApyAndRewardToken() {
        let chain = CovDF.chain()
        let viewModel = LiquidityPoolSupplyViewModelFactoryDefault().buildViewModel(
            slippage: 1,
            apy: PoolApyInfo(poolId: "p", apy: 3),
            liquidityPair: CovDF.pair(chain),
            chain: chain
        )
        XCTAssertEqual(viewModel.slippageViewModel?.title, "1.00%")
        XCTAssertEqual(viewModel.apyViewModel?.title, NumberFormatter.percentAPY.stringFromDecimal(3))
        XCTAssertEqual(viewModel.rewardTokenViewModel?.title, "PSWAP")
        XCTAssertNil(viewModel.rewardTokenIconViewModel, "the fixture asset has no icon")

        let withoutApy = LiquidityPoolSupplyViewModelFactoryDefault().buildViewModel(
            slippage: 0.5, apy: nil, liquidityPair: CovDF.pair(chain), chain: CovDFixtures.soraChain(assets: [])
        )
        XCTAssertNil(withoutApy.apyViewModel)
        XCTAssertNil(withoutApy.rewardTokenViewModel?.title)
    }
}
