import XCTest
import UIKit
import SoraFoundation
import SSFModels
@testable import fearless

final class CovJFinSwapRouter: SwapTransactionDetailRouterInput {
    var dismissals = 0
    var shared: [[Any]] = []
    var webURLs: [URL] = []
    var statuses: [String] = []

    func dismiss(view _: ControllerBackedProtocol?) { dismissals += 1 }
    func share(source _: UIActivityItemSource, from _: ControllerBackedProtocol?, with _: SharingCompletionHandler?) {}
    func share(sources: [Any], from _: ControllerBackedProtocol?, with _: SharingCompletionHandler?) { shared.append(sources) }
    func presentStatus(with viewModel: ApplicationStatusAlertEvent, animated _: Bool) { statuses.append(viewModel.titleText) }
    func dismissStatus(with _: ApplicationStatusAlertEvent?, animated _: Bool) {}
    func showWeb(url: URL, from _: ControllerBackedProtocol, style _: WebPresentableStyle) { webURLs.append(url) }
}

final class CovJFinSwapInteractor: SwapTransactionDetailInteractorInput {
    weak var output: SwapTransactionDetailInteractorOutput?
    func setup(with output: SwapTransactionDetailInteractorOutput) { self.output = output }
}

final class CovJFinSwapView: UIViewController, SwapTransactionDetailViewInput {
    var viewModels: [SwapTransactionViewModel] = []
    var explorers: [ChainModel.ExternalApiExplorer?] = []
    func didReceive(viewModel: SwapTransactionViewModel) { viewModels.append(viewModel) }
    func didReceive(explorer: ChainModel.ExternalApiExplorer?) { explorers.append(explorer) }
}

final class CovJFinSwapViewOutput: SwapTransactionDetailViewOutput {
    var calls: [String] = []
    func didLoad(view _: SwapTransactionDetailViewInput) { calls.append("load") }
    func didTapDismiss() { calls.append("dismiss") }
    func didTapCopyTxHash() { calls.append("copy") }
    func didTapSubscan() { calls.append("subscan") }
    func didTapShare() { calls.append("share") }
}

enum CovJFinSwapFixture {
    static let explorer = ChainModel.ExternalApiExplorer(type: .subscan, types: [.extrinsic], url: "https://scan.invalid/{type}/{value}")

    static func asset(id: String, symbol: String, currencyId: String, utility: Bool, precision: UInt16 = 18) -> AssetModel {
        AssetModel(
            id: id, name: symbol, symbol: symbol, precision: precision, icon: nil, currencyId: currencyId, existentialDeposit: nil,
            color: utility ? "#E3232C" : nil, isUtility: utility, isNative: utility, staking: nil, purchaseProviders: nil, type: nil,
            ethereumType: nil, priceProvider: nil, coingeckoPriceId: nil
        )
    }

    static func chainAsset(explorers: [ChainModel.ExternalApiExplorer]? = [explorer]) -> ChainAsset {
        let xor = asset(id: "xor", symbol: "xor", currencyId: "XOR-ID", utility: true)
        let val = asset(id: "val", symbol: "val", currencyId: "VAL-ID", utility: false)
        let chain = ChainModel(
            rank: nil, disabled: false, chainId: "swap-\(UUID().uuidString)", parentId: nil, paraId: nil, name: "Swapnet", xcm: nil,
            nodes: [], addressPrefix: 69, types: nil, icon: nil, options: nil,
            externalApi: ChainModel.ExternalApiSet(explorers: explorers), selectedNode: nil, customNodes: nil,
            iosMinAppVersion: nil, identityChain: nil
        )
        chain.assets = [xor, val]
        return ChainAsset(chain: chain, asset: xor)
    }

    static func transaction(status: AssetTransactionStatus, hash: String = "0xhash") -> AssetTransactionData {
        AssetTransactionData(
            transactionId: hash, status: status, assetId: "VAL-ID", peerId: "XOR-ID", peerFirstName: nil, peerLastName: nil,
            peerName: nil, details: "1.5", amount: AmountDecimal(value: 2),
            fees: [
                AssetTransactionFee(identifier: "fee", assetId: "VAL-ID", amount: AmountDecimal(value: Decimal(string: "0.25") ?? 0), context: nil),
                AssetTransactionFee(identifier: "other", assetId: "XOR-ID", amount: AmountDecimal(value: 9), context: nil)
            ],
            timestamp: 1_700_000_000, type: "swap", reason: nil, context: nil
        )
    }
}

final class CovJFinSwapTransactionDetailTests: XCTestCase {
    private let locale = CovJFixture.locale

    private func status(_ viewModel: SwapTransactionViewModel) -> (String, UIColor?) {
        (viewModel.status.string, viewModel.status.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor)
    }

    func testViewModelFactoryDescribesEveryStatusAndTheSwap() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let chainAsset = CovJFinSwapFixture.chainAsset()
        let factory = SwapTransactionViewModelFactory()

        let committed = factory.createViewModel(
            wallet: wallet, chainAsset: chainAsset, transaction: CovJFinSwapFixture.transaction(status: .commited), priceData: nil, locale: locale
        )
        XCTAssertEqual(status(committed).0, R.string.localizable.polkaswapConfirmationSwappedStub(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(status(committed).1, R.color.colorGreen())
        let pending = factory.createViewModel(
            wallet: wallet, chainAsset: chainAsset, transaction: CovJFinSwapFixture.transaction(status: .pending), priceData: nil, locale: locale
        )
        XCTAssertEqual(status(pending).0, "PENDING")
        XCTAssertEqual(status(pending).1, R.color.colorOrange())
        let rejected = factory.createViewModel(
            wallet: wallet, chainAsset: chainAsset, transaction: CovJFinSwapFixture.transaction(status: .rejected), priceData: nil, locale: locale
        )
        XCTAssertEqual(status(rejected).0, "REJECTED")
        XCTAssertEqual(status(rejected).1, R.color.colorRed())

        let from = try XCTUnwrap(Decimal(string: "1.5")?.toString(locale: locale, maximumDigits: 4))
        let to = try XCTUnwrap(Decimal(2).toString(locale: locale, maximumDigits: 4))
        XCTAssertTrue(committed.amountsText.string.hasPrefix("\(from) XOR"), committed.amountsText.string)
        XCTAssertTrue(committed.amountsText.string.hasSuffix("  \(to) VAL"), committed.amountsText.string)
        XCTAssertNotNil(committed.amountsText.attribute(.attachment, at: "\(from) XOR".count, effectiveRange: nil))
        XCTAssertEqual(committed.walletName, wallet.name)
        XCTAssertFalse(committed.address.isEmpty)
        XCTAssertEqual(committed.txHash, "0xhash")
        XCTAssertEqual(committed.date, DateFormatter.txDetails.value(for: locale).string(from: Date(timeIntervalSince1970: 1_700_000_000)))
        XCTAssertNotNil(committed.doubleImageViewViewModel.leftShadowColor)
        XCTAssertNil(committed.doubleImageViewViewModel.rightShadowColor)
        let utility = try XCTUnwrap(chainAsset.chain.utilityChainAssets().first)
        let fee = BalanceViewModelFactory(targetAssetInfo: utility.asset.displayInfo(with: nil), selectedMetaAccount: wallet)
            .balanceFromPrice(Decimal(string: "0.25") ?? 0, priceData: nil, isApproximately: true, usageCase: .detailsCrypto).value(for: locale)
        XCTAssertEqual(committed.networkFee.amount, fee.amount)

        let anonymous = factory.createViewModel(
            wallet: CovJFinClaimFixture.walletWithoutAccounts(), chainAsset: chainAsset,
            transaction: CovJFinSwapFixture.transaction(status: .pending), priceData: nil, locale: locale
        )
        XCTAssertEqual(anonymous.address, "")
    }

    func testPresenterShowsDetailsAndRoutesExplorerActions() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let chainAsset = CovJFinSwapFixture.chainAsset()
        let interactor = CovJFinSwapInteractor()
        let router = CovJFinSwapRouter()
        let presenter = SwapTransactionDetailPresenter(
            wallet: wallet, chainAsset: chainAsset, transaction: CovJFinSwapFixture.transaction(status: .commited, hash: "0xfeed"),
            viewModelFactory: SwapTransactionViewModelFactory(), interactor: interactor, router: router,
            localizationManager: LocalizationManager.shared
        )
        let view = CovJFinSwapView()
        presenter.didLoad(view: view)
        XCTAssertTrue(interactor.output === presenter)
        XCTAssertEqual(view.explorers.count, 1)
        XCTAssertEqual(view.explorers.first??.url, CovJFinSwapFixture.explorer.url)
        XCTAssertTrue(CovJWait.until { view.viewModels.count == 1 })
        XCTAssertEqual(view.viewModels.first?.txHash, "0xfeed")

        presenter.didTapSubscan()
        presenter.didTapShare()
        presenter.didTapDismiss()
        XCTAssertEqual(router.webURLs, [URL(string: "https://scan.invalid/extrinsic/0xfeed")].compactMap { $0 })
        XCTAssertEqual(router.shared.first?.first as? URL, URL(string: "https://scan.invalid/extrinsic/0xfeed"))
        XCTAssertEqual(router.dismissals, 1)
        presenter.applyLocalization()
        XCTAssertTrue(router.statuses.isEmpty)
    }

    func testPresenterWithoutSubscanIgnoresExplorerActions() {
        let router = CovJFinSwapRouter()
        let presenter = SwapTransactionDetailPresenter(
            wallet: AccountGenerator.generateMetaAccount(), chainAsset: CovJFinSwapFixture.chainAsset(explorers: nil),
            transaction: CovJFinSwapFixture.transaction(status: .pending), viewModelFactory: SwapTransactionViewModelFactory(),
            interactor: CovJFinSwapInteractor(), router: router, localizationManager: LocalizationManager.shared
        )
        presenter.didTapSubscan()
        presenter.didTapShare()
        let view = CovJFinSwapView()
        presenter.didLoad(view: view)
        XCTAssertEqual(view.explorers.count, 1)
        XCTAssertNil(view.explorers.first ?? nil)
        presenter.didTapSubscan()
        presenter.didTapShare()
        XCTAssertTrue(router.webURLs.isEmpty)
        XCTAssertTrue(router.shared.isEmpty)
        XCTAssertTrue(CovJWait.until { view.viewModels.count == 1 })
    }

    func testControllerBindsAndForwardsEveryAction() throws {
        let output = CovJFinSwapViewOutput()
        let controller = SwapTransactionDetailViewController(output: output, localizationManager: LocalizationManager.shared)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let root = try XCTUnwrap(controller.view as? SwapTransactionDetailViewLayout)
        XCTAssertEqual(output.calls, ["load"])

        let viewModel = SwapTransactionViewModelFactory().createViewModel(
            wallet: AccountGenerator.generateMetaAccount(), chainAsset: CovJFinSwapFixture.chainAsset(),
            transaction: CovJFinSwapFixture.transaction(status: .commited), priceData: nil, locale: locale
        )
        controller.didReceive(viewModel: viewModel)
        controller.didReceive(explorer: CovJFinSwapFixture.explorer)
        XCTAssertEqual(root.amountsLabel.attributedText?.string, viewModel.amountsText.string)
        XCTAssertEqual(root.fromView.valueTop.text, viewModel.walletName)
        XCTAssertFalse(root.subscanButton.isHidden)
        controller.didReceive(explorer: nil)
        XCTAssertTrue(root.shareButton.isHidden)

        root.closeButton.sendActions(for: .touchUpInside)
        root.subscanButton.sendActions(for: .touchUpInside)
        root.shareButton.sendActions(for: .touchUpInside)
        root.copyOnTap?()
        XCTAssertEqual(output.calls, ["load", "dismiss", "subscan", "share", "copy"])
        controller.applyLocalization()
        XCTAssertEqual(root.locale, controller.selectedLocale)
    }

    func testAssemblyBuildsAModuleThatLoadsTheTransaction() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let module = try XCTUnwrap(SwapTransactionDetailAssembly.configureModule(
            wallet: wallet, chainAsset: CovJFinSwapFixture.chainAsset(), transaction: CovJFinSwapFixture.transaction(status: .commited)
        ))
        XCTAssertTrue(module.input is SwapTransactionDetailPresenter)
        let controller = try XCTUnwrap(module.view.controller as? SwapTransactionDetailViewController)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let root = try XCTUnwrap(controller.view as? SwapTransactionDetailViewLayout)
        XCTAssertTrue(CovJWait.until { root.fromView.valueTop.text == wallet.name })
        XCTAssertFalse(root.subscanButton.isHidden)
    }
}
