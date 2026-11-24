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

final class CovDLiquiditySupplyConfirmTests: XCTestCase {
    typealias CovDF = CovDLiquidityFixtures
    private var window: UIWindow?

    override func tearDown() {
        CovDFixtures.tearDown(window)
        window = nil
        super.tearDown()
    }

    func testConfirmScreenBindsTermsFeeAndGuardsSubmission() throws {
        let chain = CovDF.chain()
        let router = CovDSupplyConfirmRouterSpy()
        let interactor = CovDSupplyConfirmInteractorSpy()
        var hashes: [String] = []
        let presenter = LiquidityPoolSupplyConfirmPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            dataValidatingFactory: SendDataValidatingFactory(presentable: router),
            logger: Logger.shared,
            liquidityPair: CovDF.pair(chain),
            chain: chain,
            inputData: LiquidityPoolSupplyConfirmInputData(
                baseAssetAmount: 1, targetAssetAmount: 2, slippageTolerance: Decimal(string: "0.5")!, availablePools: nil
            ),
            wallet: CovDFixtures.wallet(),
            viewModelFactory: LiquidityPoolSupplyConfirmViewModelFactoryDefault(),
            didSubmitTransactionClosure: { hashes.append($0) },
            submissionAuthorizer: CovDSubmissionAuthorizerStub()
        )
        let controller = LiquidityPoolSupplyConfirmViewController(output: presenter, localizationManager: LocalizationManager.shared)
        window = try CovDFixtures.host(UINavigationController(rootViewController: controller))
        if interactor.feeRequests.isEmpty { presenter.handleViewAppeared() }
        let layout = controller.rootView
        XCTAssertTrue(interactor.output === presenter)
        XCTAssertEqual(interactor.feeRequests.last?.baseAssetAmount, 1)
        XCTAssertEqual(interactor.feeRequests.last?.targetAssetAmount, 2)
        XCTAssertTrue(CovDFixtures.spin { layout.amountsLabel.attributedText?.string.contains("VAL") == true })
        XCTAssertEqual(layout.slippageView.valueTop.text, "0.50%")
        XCTAssertEqual(layout.rewardTokenView.valueTop.text, "PSWAP")

        presenter.didReceivePoolAPY(apyInfo: PoolApyInfo(poolId: "p", apy: 7))
        XCTAssertNotNil(layout.apyView.valueTop.text)
        presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: CovDF.planks(5))), for: CovDF.chainAsset(chain, CovDF.xor))
        presenter.didReceiveAccountInfo(result: .success(nil), for: CovDF.chainAsset(chain, CovDF.val))
        presenter.didReceiveAccountInfo(result: .failure(CovDTestError.offline), for: CovDF.chainAsset(chain, CovDF.val))
        presenter.didReceiveFee(CovDF.planks(Decimal(string: "0.03")!))
        XCTAssertTrue(CovDFixtures.spin { layout.networkFeeView.valueTop.text?.contains("0.03") == true })

        layout.confirmButton.sendActions(for: .touchUpInside)
        if let title = router.infoTitles.last {
            XCTAssertTrue(["Liquidity actions paused", "Liquidity actions unavailable"].contains(title), title)
            XCTAssertTrue(interactor.submissions.isEmpty)
        } else {
            XCTAssertEqual(interactor.submissions.first?.baseAssetAmount, 1)
        }
        presenter.didTapApyInfo()
        presenter.didTapFeeInfo()
        XCTAssertGreaterThanOrEqual(router.infoTitles.count, 2)
        layout.backButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(router.dismissCount, 1)

        presenter.didReceiveSubmitError(error: CovDTestError.offline)
        XCTAssertEqual(router.errors, ["CovD offline"])
        presenter.didReceiveTransactionHash("0xsupplied")
        XCTAssertEqual(hashes, ["0xsupplied"])
        XCTAssertEqual(router.completions, ["0xsupplied"])
        presenter.didReceiveFeeError(CovDTestError.offline)
        presenter.didReceivePoolApyError(error: CovDTestError.offline)
        presenter.applyLocalization()
    }
}

final class CovDLiquidityDetailsTests: XCTestCase {
    typealias CovDF = CovDLiquidityFixtures
    private var window: UIWindow?

    override func tearDown() {
        CovDFixtures.tearDown(window)
        window = nil
        super.tearDown()
    }

    private func viewModelFactory() -> LiquidityPoolDetailsViewModelFactoryDefault {
        LiquidityPoolDetailsViewModelFactoryDefault(
            modelFactory: LiquidityPoolsModelFactoryDefault(),
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        )
    }

    private func reserves() -> PolkaswapPoolReservesInfo {
        CovDLiquidityReserves.make(poolId: "\(CovDF.xor)-\(CovDF.val)", reserves: CovDF.planks(100), fee: CovDF.planks(200))
    }

    func testInputExposesEveryCase() {
        let chain = CovDF.chain()
        let pair = CovDF.pair(chain)
        let apy = PoolApyInfo(poolId: "p", apy: 1)
        let user = LiquidityPoolDetailsInput.userPool(
            liquidityPair: pair, reserves: reserves(), apyInfo: apy, accountPool: CovDF.accountPool(chain), availablePairs: [pair]
        )
        let available = LiquidityPoolDetailsInput.availablePool(liquidityPair: pair, reserves: reserves(), apyInfo: apy, availablePairs: [])
        XCTAssertTrue(user.isUserPool)
        XCTAssertEqual(user.availablePairs?.count, 1)
        XCTAssertEqual(user.liquidityPair?.pairId, pair.pairId)
        XCTAssertEqual(user.reserves?.poolId, "\(CovDF.xor)-\(CovDF.val)")
        XCTAssertEqual(user.apyInfo?.apy, 1)
        XCTAssertEqual(user.accountPool?.baseAssetPooled, 4)
        XCTAssertFalse(available.isUserPool)
        XCTAssertEqual(available.availablePairs?.count, 0)
        XCTAssertNotNil(available.liquidityPair)
        XCTAssertNotNil(available.reserves)
        XCTAssertNotNil(available.apyInfo)
        XCTAssertNil(available.accountPool)
        let initial = LiquidityPoolDetailsInput.initial
        XCTAssertFalse(initial.isUserPool)
        XCTAssertNil(initial.availablePairs)
        XCTAssertNil(initial.liquidityPair)
        XCTAssertNil(initial.reserves)
        XCTAssertNil(initial.apyInfo)
        XCTAssertNil(initial.accountPool)
    }

    func testUserPoolDetailsBindValuesAndRouteActions() throws {
        let chain = CovDF.chain()
        let pair = CovDF.pair(chain)
        let router = CovDDetailsRouterSpy()
        let interactor = CovDDetailsInteractorSpy()
        let presenter = LiquidityPoolDetailsPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            assetIdPair: AssetIdPair(baseAssetIdCode: CovDF.xor, targetAssetIdCode: CovDF.val),
            logger: Logger.shared,
            viewModelFactory: viewModelFactory(),
            chain: chain,
            wallet: CovDFixtures.wallet(),
            input: .userPool(
                liquidityPair: pair, reserves: reserves(), apyInfo: PoolApyInfo(poolId: "p", apy: 9),
                accountPool: CovDF.accountPool(chain), availablePairs: [pair]
            ),
            didSubmitTransactionClosure: { _ in }
        )
        let controller = LiquidityPoolDetailsViewController(output: presenter, localizationManager: LocalizationManager.shared)
        window = try CovDFixtures.host(controller)
        XCTAssertTrue(interactor.output === presenter)
        presenter.didReceiveLiquidityPair(liquidityPair: pair)
        let layout = controller.rootView
        XCTAssertEqual(layout.pairTitleLabel.text, "XOR › VAL")
        XCTAssertTrue(layout.reservesView.valueTop.text?.contains("700") == true, layout.reservesView.valueTop.text ?? "nil")
        XCTAssertNotNil(layout.apyView.valueTop.text)
        XCTAssertEqual(layout.rewardTokenView.valueTop.text, "PSWAP")
        XCTAssertFalse(layout.removeButton.isHidden)
        XCTAssertFalse(layout.baseAssetPooledView.isHidden)
        XCTAssertTrue(layout.baseAssetPooledView.titleLabel.text?.contains("XOR") == true)
        XCTAssertTrue(layout.targetAssetPooledView.valueTop.text?.contains("8") == true)

        presenter.didReceiveUserPool(pool: CovDF.accountPool(chain, base: 1, target: 2))
        XCTAssertTrue(layout.targetAssetPooledView.valueTop.text?.contains("2") == true)
        presenter.didReceivePoolReserves(reserves: CachedStorageResponse(value: nil, type: .remote))
        presenter.didReceivePoolAPY(apy: nil)

        layout.supplyButton.sendActions(for: .touchUpInside)
        layout.removeButton.sendActions(for: .touchUpInside)
        layout.navigationBar.backButton.sendActions(for: .touchUpInside)
        presenter.didTapApyInfo()
        XCTAssertEqual(router.supplyPairs, [pair.pairId])
        XCTAssertEqual(router.removePairs, [pair.pairId])
        XCTAssertEqual(router.dismissCount, 1)
        XCTAssertEqual(router.infoTitles.count, 1)

        presenter.didReceiveLiquidityPairError(error: CovDTestError.offline)
        presenter.didReceiveUserPoolError(error: CovDTestError.offline)
        presenter.didReceivePoolReservesError(error: CovDTestError.offline)
        presenter.didReceivePoolApyError(error: CovDTestError.offline)
        presenter.applyLocalization()
        controller.applyLocalization()
    }

    func testAvailablePoolHidesUserFieldsAndInitialInputDoesNothing() throws {
        let chain = CovDF.chain()
        let pair = CovDF.pair(chain)
        let router = CovDDetailsRouterSpy()
        func make(_ input: LiquidityPoolDetailsInput) -> LiquidityPoolDetailsPresenter {
            LiquidityPoolDetailsPresenter(
                interactor: CovDDetailsInteractorSpy(),
                router: router,
                localizationManager: LocalizationManager.shared,
                assetIdPair: AssetIdPair(baseAssetIdCode: CovDF.xor, targetAssetIdCode: CovDF.val),
                logger: Logger.shared,
                viewModelFactory: viewModelFactory(),
                chain: chain,
                wallet: CovDFixtures.wallet(),
                input: input,
                didSubmitTransactionClosure: { _ in }
            )
        }
        let available = make(.availablePool(liquidityPair: pair, reserves: nil, apyInfo: nil, availablePairs: nil))
        let controller = LiquidityPoolDetailsViewController(output: available, localizationManager: LocalizationManager.shared)
        window = try CovDFixtures.host(controller)
        available.didReceivePoolAPY(apy: PoolApyInfo(poolId: "p", apy: nil))
        XCTAssertTrue(controller.rootView.removeButton.isHidden)
        XCTAssertTrue(controller.rootView.baseAssetPooledView.isHidden)
        XCTAssertNil(controller.rootView.reservesView.valueTop.text)

        let initial = make(.initial)
        initial.supplyButtonClicked()
        initial.removeButtonClicked()
        initial.didReceivePoolAPY(apy: nil)
        XCTAssertTrue(router.supplyPairs.isEmpty)
        XCTAssertTrue(router.removePairs.isEmpty)

        XCTAssertNil(viewModelFactory().buildViewModel(
            liquidityPair: pair, reserves: nil, apyInfo: nil, chain: CovDFixtures.soraChain(assets: []),
            locale: Locale(identifier: "en_US"), wallet: CovDFixtures.wallet(), accountPoolInfo: nil, input: .initial
        ))
    }

    func testModelFactoryNeedsAssetsReservesAndBothPrices() {
        let chain = CovDF.chain()
        let factory = LiquidityPoolsModelFactoryDefault()
        let base = PriceData(currencyId: "usd", priceId: "a", price: "3", fiatDayChange: nil, coingeckoPriceId: nil)
        let target = PriceData(currencyId: "usd", priceId: "b", price: "2", fiatDayChange: nil, coingeckoPriceId: nil)
        XCTAssertEqual(factory.buildReserves(
            pool: CovDF.pair(chain), chain: chain, reservesInfo: reserves(), baseAssetPrice: base, targetAssetPrice: target
        ), 700)
        XCTAssertEqual(factory.buildReserves(
            accountPool: CovDF.accountPool(chain), chain: chain, reservesInfo: reserves(), baseAssetPrice: base, targetAssetPrice: target
        ), 700)
        XCTAssertNil(factory.buildReserves(
            pool: CovDF.pair(chain), chain: chain, reservesInfo: reserves(), baseAssetPrice: base, targetAssetPrice: nil
        ))
        XCTAssertNil(factory.buildReserves(
            pool: CovDF.pair(chain), chain: chain, reservesInfo: nil, baseAssetPrice: base, targetAssetPrice: target
        ))
        XCTAssertNil(factory.buildReserves(
            pool: CovDF.pair(chain), chain: CovDFixtures.soraChain(assets: []), reservesInfo: reserves(),
            baseAssetPrice: base, targetAssetPrice: target
        ))
        XCTAssertEqual(CovDF.pair(chain).dexId, "0")
        let mapped = CovDF.accountPool(chain, reservesId: "0xreserves").liquidityPair
        XCTAssertEqual(mapped.pairId, "\(CovDF.xor)-\(CovDF.val)")
        XCTAssertEqual(mapped.reservesId, "0xreserves")
    }
}
