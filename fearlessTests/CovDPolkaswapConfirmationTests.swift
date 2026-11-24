import BigInt
import Foundation
import SoraFoundation
import SoraKeystore
import SSFModels
import UIKit
import XCTest

@testable import fearless

final class CovDSwapConfirmationRouterSpy: CovDRouterSpy, PolkaswapSwapConfirmationRouterInput {
    private(set) var completions: [String] = []

    func complete(on _: ControllerBackedProtocol?, hashString: String, chainAsset _: ChainAsset, completeClosure: (() -> Void)?) {
        completions.append(hashString)
        completeClosure?()
    }
}

final class CovDSwapConfirmationInteractorSpy: PolkaswapSwapConfirmationInteractorInput {
    private(set) weak var output: PolkaswapSwapConfirmationInteractorOutput?
    private(set) var updates: [Decimal] = []
    private(set) var submissions = 0

    func setup(with output: PolkaswapSwapConfirmationInteractorOutput) { self.output = output }
    func update(params: PolkaswapPreviewParams) { updates.append(params.fromAmount) }
    func submit() { submissions += 1 }
}

enum CovDSwapFixtures {
    static let tokenId = "0x" + String(repeating: "01", count: 32)

    static func chain(chainId: String = Chain.soraMain.genesisHash) -> ChainModel {
        CovDFixtures.soraChain(chainId: chainId, assets: [
            AssetModel(
                id: "xor", name: "SORA", symbol: "XOR", precision: 18, currencyId: PolkamarktConstants.feeAssetId,
                isUtility: true, isNative: true, type: .soraAsset
            ),
            AssetModel(
                id: "tkn", name: "Token", symbol: "TKN", precision: 18, currencyId: tokenId,
                isUtility: false, isNative: false, type: .soraAsset
            )
        ])
    }

    static func params(
        chain: ChainModel = chain(),
        wallet: MetaAccountModel = CovDFixtures.wallet(),
        from: Decimal = 2,
        to: Decimal = 1,
        variant: SwapVariant = .desiredInput,
        minMax: Decimal = 1,
        reversed: Bool = false
    ) -> PolkaswapPreviewParams {
        let xor = chain.chainAssets.first { $0.asset.symbol == "XOR" }!
        let token = chain.chainAssets.first { $0.asset.symbol == "TKN" }!
        return PolkaswapPreviewParams(
            wallet: wallet,
            soraChinAsset: xor,
            swapFromChainAsset: reversed ? token : xor,
            swapToChainAsset: reversed ? xor : token,
            fromAmount: from,
            toAmount: to,
            slippadgeTolerance: 0.5,
            swapVariant: variant,
            market: .smart,
            polkaswapDexForRoute: PolkaswapDex(name: "SORA", code: 0, assetId: PolkamarktConstants.feeAssetId),
            networkFee: BalanceViewModel(amount: "0.01 XOR", price: "$0.03"),
            detailsViewModel: PolkaswapAdjustmentDetailsViewModel(
                minMaxReceiveVieModel: nil,
                minMaxReceiveValue: minMax,
                route: "XOR → TKN",
                fromPerToTitle: "XOR per TKN",
                fromPerToValue: "2",
                toPerFromTitle: "TKN per XOR",
                toPerFromValue: "0.5"
            ),
            minMaxValue: minMax
        )
    }
}

final class CovDPolkaswapConfirmationTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        CovDFixtures.tearDown(window)
        window = nil
        super.tearDown()
    }

    func testConfirmationScreenShowsQuoteAndHandlesResults() throws {
        let router = CovDSwapConfirmationRouterSpy()
        let interactor = CovDSwapConfirmationInteractorSpy()
        var completed = 0
        let presenter = PolkaswapSwapConfirmationPresenter(
            params: CovDSwapFixtures.params(),
            viewModelFactory: PolkaswapSwapConfirmationViewModelFactory(),
            interactor: interactor,
            router: router,
            completeClosure: { completed += 1 },
            localizationManager: LocalizationManager.shared,
            submissionAuthorizer: CovDSubmissionAuthorizerStub()
        )
        let controller = PolkaswapSwapConfirmationViewController(output: presenter, localizationManager: LocalizationManager.shared)
        window = try CovDFixtures.host(UINavigationController(rootViewController: controller))
        XCTAssertTrue(interactor.output === presenter)
        let labels = CovDFixtures.allLabels(in: controller.view).compactMap(\.text)
        XCTAssertTrue(labels.contains { $0.contains("XOR") }, labels.joined(separator: "|"))

        presenter.updateModule(with: CovDSwapFixtures.params(from: 3, variant: .desiredOutput))
        XCTAssertEqual(interactor.updates, [3])
        presenter.didTapConfirmButton()
        if MultiChainFeaturePolicy.current.polkaswapMutationsEnabled {
            XCTAssertEqual(interactor.submissions, 1)
        } else {
            XCTAssertEqual(router.infoTitles, ["Polkaswap actions paused"])
            XCTAssertEqual(interactor.submissions, 0)
        }
        presenter.didReceive(extrinsicResult: .success("0xswap"))
        XCTAssertEqual(router.completions, ["0xswap"])
        XCTAssertEqual(completed, 1)
        presenter.didReceive(extrinsicResult: .failure(CovDTestError.offline))
        XCTAssertEqual(router.errors, ["CovD offline"])
        presenter.didTapBackButton()
        XCTAssertEqual(router.dismissCount, 1)
        presenter.applyLocalization()
    }

    func testViewModelFactoryDescribesBothSwapDirections() {
        let factory = PolkaswapSwapConfirmationViewModelFactory()
        let locale = Locale(identifier: "en_US")
        let input = factory.createViewModel(with: CovDSwapFixtures.params(), locale: locale)
        let output = factory.createViewModel(with: CovDSwapFixtures.params(variant: .desiredOutput), locale: locale)
        XCTAssertTrue(input.amountsText.string.hasPrefix("2"), input.amountsText.string)
        XCTAssertTrue(input.amountsText.string.contains("XOR"))
        XCTAssertTrue(input.amountsText.string.contains("TKN"))
        XCTAssertEqual(input.adjustmentDetailsViewModel.route, "XOR → TKN")
        XCTAssertEqual(input.networkFee.amount, "0.01 XOR")
        XCTAssertNotEqual(input.minMaxTitle, output.minMaxTitle)
    }

    func testSubmissionErrorsResolvedAmountsAndFeeCoverage() throws {
        let all: [PolkaswapSubmissionError] = [
            .actionsPaused, .disclaimerRequired, .selectedWalletChanged, .soraRuntimeUnavailable, .accountUnavailable,
            .watchOnly, .unregisteredAsset, .invalidAmount, .balanceUnavailable, .insufficientInputBalance,
            .insufficientFeeBalance
        ]
        XCTAssertEqual(Set(all.compactMap(\.errorDescription)).count, all.count)

        XCTAssertThrowsError(try PolkaswapSwapResolvedAmounts.resolve(CovDSwapFixtures.params(from: 0))) {
            XCTAssertEqual($0 as? PolkaswapSubmissionError, .invalidAmount)
        }
        let input = try PolkaswapSwapResolvedAmounts.resolve(CovDSwapFixtures.params(from: 2, to: 1, minMax: 1))
        XCTAssertEqual(input.desired, CovDLiquidityFixtures.planks(2))
        XCTAssertEqual(input.requiredInput, input.desired)
        let output = try PolkaswapSwapResolvedAmounts.resolve(
            CovDSwapFixtures.params(from: 2, to: 1, variant: .desiredOutput, minMax: 3)
        )
        XCTAssertEqual(output.desired, CovDLiquidityFixtures.planks(1))
        XCTAssertEqual(output.requiredInput, CovDLiquidityFixtures.planks(3))

        XCTAssertTrue(PolkaswapFeeCoverage.isSufficient(
            inputIsXor: false, outputIsXor: false, swapVariant: .desiredInput, amounts: input, xorBalance: 5, fee: 5
        ))
        XCTAssertFalse(PolkaswapFeeCoverage.isSufficient(
            inputIsXor: false, outputIsXor: true, swapVariant: .desiredOutput,
            amounts: PolkaswapSwapResolvedAmounts(desired: 1, slip: 9, requiredInput: 9), xorBalance: 0, fee: 2
        ))
    }

    func testRegisteredAssetResolverAndCallBuilder() throws {
        let chain = CovDSwapFixtures.chain()
        let params = CovDSwapFixtures.params(chain: chain)
        XCTAssertEqual(
            try PolkaswapRegisteredAssetResolver.exactAsset(params.swapToChainAsset, in: chain).asset.currencyId,
            CovDSwapFixtures.tokenId
        )
        XCTAssertEqual(
            try PolkaswapRegisteredAssetResolver.exactXorAsset(params.soraChinAsset, in: chain).asset.symbol,
            "XOR"
        )
        let otherChain = CovDSwapFixtures.chain(chainId: "covd-other")
        XCTAssertThrowsError(try PolkaswapRegisteredAssetResolver.exactAsset(params.swapToChainAsset, in: otherChain))
        XCTAssertThrowsError(try PolkaswapRegisteredAssetResolver.exactXorAsset(params.swapToChainAsset, in: chain))

        let builder = try PolkaswapSwapCallBuilder(
            callFactory: SubstrateCallFactoryDefault(runtimeService: CovDRuntimeProviderStub())
        ).builder(for: params)
        let spy = CovDExtrinsicBuilderSpy()
        _ = try builder(spy)
        XCTAssertEqual(spy.calls.first?.module, "LiquidityProxy")
        XCTAssertEqual(spy.calls.first?.call, "swap")

        let sameAsset = CovDSwapFixtures.params(chain: chain, reversed: false)
        let broken = PolkaswapPreviewParams(
            wallet: sameAsset.wallet, soraChinAsset: sameAsset.soraChinAsset, swapFromChainAsset: sameAsset.soraChinAsset,
            swapToChainAsset: sameAsset.soraChinAsset, fromAmount: 1, toAmount: 1, slippadgeTolerance: 0.5,
            swapVariant: .desiredInput, market: .smart, polkaswapDexForRoute: sameAsset.polkaswapDexForRoute,
            networkFee: sameAsset.networkFee, detailsViewModel: sameAsset.detailsViewModel, minMaxValue: 1
        )
        XCTAssertThrowsError(try PolkaswapSwapCallBuilder(
            callFactory: SubstrateCallFactoryDefault(runtimeService: CovDRuntimeProviderStub())
        ).builder(for: broken)) { XCTAssertEqual($0 as? PolkaswapSubmissionError, .unregisteredAsset) }
    }

    func testSubmissionAuthorizerFailsClosedBeforeRuntimeWork() async {
        let wallet = CovDFixtures.wallet()
        let settings = InMemorySettingsManager()
        PolkaswapDisclaimerPolicy.acceptCurrentVersion(in: settings)
        let authorizer = PolkaswapSubmissionAuthorizer(
            chainRegistry: CovDRegistryStub(),
            settings: settings,
            keystore: InMemoryKeychain(),
            accountInfoFetching: nil,
            selectedWallet: { wallet }
        )
        do {
            _ = try await authorizer.authorize(params: CovDSwapFixtures.params(wallet: wallet))
            XCTFail("expected a fail-closed error")
        } catch {
            let expected: [PolkaswapSubmissionError] = [.actionsPaused, .soraRuntimeUnavailable]
            XCTAssertTrue(expected.contains(error as? PolkaswapSubmissionError ?? .watchOnly), "\(error)")
        }
    }
}
