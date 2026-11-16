import XCTest
import UIKit
import SafariServices
import SSFModels
@testable import fearless

/// Records presentations and pushes instead of performing them, so routed screens are built but never shown.
final class CovHChainAccountNavigationSpy: UINavigationController {
    var presented: [UIViewController] = []
    var pushed: [UIViewController] = []
    var pops = 0
    var isRecording = false

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion: (() -> Void)? = nil) {
        presented.append(viewControllerToPresent)
        completion?()
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        guard isRecording else {
            return super.pushViewController(viewController, animated: animated)
        }
        pushed.append(viewController)
    }

    override func popViewController(animated: Bool) -> UIViewController? {
        guard isRecording else {
            return super.popViewController(animated: animated)
        }
        pops += 1
        return nil
    }
}

final class CovHChainAccountWireframeHost: UIViewController, ChainAccountViewProtocol {
    var presented: [UIViewController] = []
    var contentInsets: UIEdgeInsets = .zero
    var preferredContentHeight: CGFloat = 0
    var observable = ViewModelObserverContainer<ContainableObserver>()
    var contentView: UIView { view }

    func setContentInsets(_: UIEdgeInsets, animated _: Bool) {}
    func didReceiveState(_: ChainAccountViewState) {}
    func didReceive(balanceViewModel _: ChainAccountBalanceViewModel?) {}

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion: (() -> Void)? = nil) {
        presented.append(viewControllerToPresent)
        completion?()
    }
}

enum CovHChainAccountSheetReader {
    static func model(of controller: UIViewController?) -> SheetAlertPresentableViewModel? {
        guard let sheet = controller as? SheetAletViewController else {
            return nil
        }
        return Mirror(reflecting: sheet).children.first { $0.label == "viewModel" }?.value as? SheetAlertPresentableViewModel
    }
}

final class CovHChainAccountWireframeTests: XCTestCase {
    private let wireframe = ChainAccountWireframe()
    private let host = CovHChainAccountWireframeHost()
    private var navigation: CovHChainAccountNavigationSpy!
    private let chainAsset = CovHChainAccountFixture.chainAsset()
    private let wallet = CovHChainAccountFixture.wallet()

    override func setUp() {
        super.setUp()
        navigation = CovHChainAccountNavigationSpy(rootViewController: host)
        navigation.isRecording = true
        XCTAssertTrue(host.navigationController === navigation)
    }

    private var purchaseAction: PurchaseAction {
        PurchaseAction(title: "Ramp", url: URL(string: "https://app.ramp.network/") ?? URL(fileURLWithPath: "/"), icon: UIImage())
    }

    func testCloseAndDetailsUseTheNavigationStack() {
        wireframe.close(view: host)
        XCTAssertEqual(navigation.pops, 1)
        wireframe.showDetails(from: host, chainAsset: chainAsset, wallet: wallet)
        XCTAssertLessThanOrEqual(navigation.pushed.count, 1)
        XCTAssertTrue(navigation.pushed.allSatisfy { $0 is WalletChainAccountDashboardViewController })
    }

    func testCrossChainWithoutAReviewedRouteExplainsWhy() throws {
        wireframe.presentCrossChainFlow(from: host, chainAsset: chainAsset, wallet: wallet)
        let alert = try XCTUnwrap(host.presented.last as? UIAlertController)
        XCTAssertTrue(["Cross-chain route unavailable", "No supported route"].contains(alert.title ?? ""))
        XCTAssertEqual(alert.actions.map(\.title), ["OK"])
    }

    func testPickersArePresentedOnlyForNonEmptyLists() {
        let delegate = CovHChainAccountPresenterContext(chainAsset: chainAsset).presenter
        wireframe.presentBuyFlow(from: host, items: [], delegate: delegate)
        wireframe.presentChainActionsFlow(from: host, items: [], chain: chainAsset.chain) { _ in }
        wireframe.showUniqueChainSourceSelection(from: host, items: []) { _ in }
        XCTAssertTrue(navigation.presented.isEmpty)

        wireframe.presentBuyFlow(from: host, items: [purchaseAction], delegate: delegate)
        wireframe.presentChainActionsFlow(from: host, items: [.export, .switchNode], chain: chainAsset.chain) { _ in }
        wireframe.showUniqueChainSourceSelection(from: host, items: ReplaceChainOption.allCases) { _ in }
        XCTAssertEqual(navigation.presented.count, 3)
        XCTAssertTrue(host.presented.isEmpty)
    }

    func testPurchaseNodeAndNetworkScreensArePresented() {
        wireframe.presentPurchaseWebView(from: host, action: purchaseAction)
        XCTAssertTrue(host.presented.last is PurchaseViewController)
        wireframe.presentNodeSelection(from: host, chain: chainAsset.chain)
        XCTAssertTrue(host.presented.last is NodeSelectionViewController)
        wireframe.showSelectNetwork(
            from: host, wallet: wallet, selectedChainId: chainAsset.chain.chainId, chainModels: [chainAsset.chain], delegate: nil
        )
        XCTAssertTrue(host.presented.last is SelectNetworkViewController)
        XCTAssertEqual(host.presented.count, 3)
    }

    func testFlowsNeedingAChainConnectionAreNotOpened() {
        wireframe.presentLockedInfo(from: host, chainAsset: chainAsset, wallet: wallet)
        wireframe.showClaimCrowdloanRewardsFlow(from: host, chainAsset: chainAsset, wallet: wallet)
        XCTAssertTrue(host.presented.isEmpty)
        XCTAssertTrue(navigation.presented.isEmpty)
    }

    func testCreateIsPushedWithoutTheTabBar() throws {
        wireframe.showCreate(uniqueChainModel: UniqueChainModel(meta: wallet, chain: chainAsset.chain), from: host)
        let controller = try XCTUnwrap(navigation.pushed.last)
        XCTAssertTrue(controller is AccountCreateViewController)
        XCTAssertTrue(controller.hidesBottomBarWhenPushed)
    }

    func testExportSheetAuthorizesEachOptionBeforePushingItsScreen() throws {
        let address = try XCTUnwrap(wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress())
        let locale = Locale(identifier: "en")
        wireframe.showExport(for: address, chain: chainAsset.chain, options: [.mnemonic, .keystore, .seed], locale: locale, wallet: wallet, from: host)
        let model = try XCTUnwrap(CovHChainAccountSheetReader.model(of: host.presented.last))
        XCTAssertEqual(model.title, R.string.localizable.importSourcePickerTitle(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(model.closeAction, R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(model.actions.map(\.title), [
            R.string.localizable.importMnemonic(preferredLanguages: locale.rLanguages),
            R.string.localizable.importRecoveryJson(preferredLanguages: locale.rLanguages),
            R.string.localizable.importRawSeed(preferredLanguages: locale.rLanguages)
        ])

        for action in model.actions {
            action.handler?()
            XCTAssertTrue(host.presented.last is PinSetupViewController, "every export asks for the PIN first")
            wireframe.showAuthorizationCompletion(with: true)
        }
        XCTAssertEqual(navigation.pushed.count, 3)
        XCTAssertTrue(navigation.pushed[0] is ExportGenericViewController)
        XCTAssertTrue(navigation.pushed[1] is AccountExportPasswordViewController)
        XCTAssertTrue(navigation.pushed[2] is ExportGenericViewController)
    }

    func testRejectedAuthorizationPushesNothing() throws {
        let address = try XCTUnwrap(wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress())
        wireframe.showExport(for: address, chain: chainAsset.chain, options: [.keystore], locale: nil, wallet: wallet, from: host)
        let model = try XCTUnwrap(CovHChainAccountSheetReader.model(of: host.presented.last))
        model.actions.first?.handler?()
        wireframe.showAuthorizationCompletion(with: false)
        XCTAssertTrue(navigation.pushed.isEmpty)
    }
}
