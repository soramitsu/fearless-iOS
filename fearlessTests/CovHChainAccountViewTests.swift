import XCTest
import UIKit
import SoraFoundation
import SSFModels
@testable import fearless

final class CovHChainAccountPresenterSpy: ChainAccountPresenterProtocol {
    var calls: [String] = []
    func setup() { calls.append("setup") }
    func didTapBackButton() { calls.append("back") }
    func didTapSendButton() { calls.append("send") }
    func didTapReceiveButton() { calls.append("receive") }
    func didTapBuyButton() { calls.append("buy") }
    func didTapOptionsButton() { calls.append("options") }
    func didTapCrossChainButton() { calls.append("crossChain") }
    func didTapSelectNetwork() { calls.append("network") }
    func addressDidCopied() { calls.append("copied") }
    func didTapPolkaswapButton() { calls.append("polkaswap") }
    func didTapLockedInfoButton() { calls.append("locked") }
    func didPullToRefresh() { calls.append("refresh") }
}

enum CovHChainAccountViewInspector {
    static func texts(in view: UIView) -> [String] {
        var result: [String] = []
        if let label = view as? UILabel, let text = label.text, !text.isEmpty {
            result.append(text)
        }
        if let button = view as? UIButton, let title = button.title(for: .normal), !title.isEmpty {
            result.append(title)
        }
        view.subviews.forEach { result.append(contentsOf: texts(in: $0)) }
        return result
    }

    static func host(_ controller: UIViewController) -> UIWindow {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map(UIWindow.init(windowScene:)) ?? UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()
        return window
    }
}

final class CovHChainAccountViewTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        super.tearDown()
    }

    private func makeController(mode: ChainAccountViewMode) -> (ChainAccountViewController, CovHChainAccountPresenterSpy, UIViewController) {
        let presenter = CovHChainAccountPresenterSpy()
        let balance = UIViewController()
        let controller = ChainAccountViewController(
            presenter: presenter,
            balanceInfoViewController: balance,
            localizationManager: LocalizationManager.shared,
            mode: mode
        )
        window = CovHChainAccountViewInspector.host(controller)
        return (controller, presenter, balance)
    }

    func testLoadEmbedsBalanceAndForwardsEveryButton() {
        let (controller, presenter, balance) = makeController(mode: .extended)
        XCTAssertTrue(balance.parent === controller)
        XCTAssertTrue(balance.view.superview === controller.rootView.walletBalanceViewContainer)
        XCTAssertEqual(presenter.calls, ["setup"])

        let root = controller.rootView
        [root.backButton, root.optionsButton, root.sendButton, root.receiveButton, root.buyButton,
         root.crossChainButton, root.selectNetworkButton, root.polkaswapButton, root.infoButton].forEach {
            $0.sendActions(for: .touchUpInside)
        }
        root.addressCopyableLabel.onСopied?()
        controller.reload()
        XCTAssertEqual(
            presenter.calls,
            ["setup", "back", "options", "send", "receive", "buy", "crossChain", "network", "polkaswap", "locked", "copied", "refresh"]
        )
    }

    func testExtendedViewModelShowsAddressActionsAndChainName() {
        let (controller, _, _) = makeController(mode: .extended)
        controller.didReceiveState(.loading)
        controller.didReceiveState(.error)
        controller.didReceiveState(.loaded(CovHChainAccountFixture.viewModel(name: "Cov wallet", mode: .extended, address: "cov-address")))
        controller.view.layoutIfNeeded()
        let root = controller.rootView
        XCTAssertFalse(root.sendButton.isHidden)
        XCTAssertTrue(root.buyButton.isHidden)
        XCTAssertFalse(root.polkaswapButton.isHidden)
        XCTAssertTrue(root.crossChainButton.isHidden)
        XCTAssertFalse(root.actionsView.isHidden)
        XCTAssertFalse(root.optionsButton.isHidden)
        XCTAssertFalse(root.addressCopyableLabel.isHidden)
        let texts = CovHChainAccountViewInspector.texts(in: root)
        XCTAssertTrue(texts.contains("Cov wallet"))
        XCTAssertTrue(texts.contains("Coverage chain"))
        XCTAssertTrue(texts.contains { $0.contains("cov-address") })

        controller.didReceiveState(.loaded(CovHChainAccountFixture.viewModel(mode: .extended, address: nil)))
        XCTAssertTrue(root.addressCopyableLabel.isHidden)
    }

    func testSimpleViewModelHidesAccountControls() {
        let (controller, _, _) = makeController(mode: .simple)
        controller.didReceiveState(.loaded(CovHChainAccountFixture.viewModel(mode: .simple)))
        let root = controller.rootView
        XCTAssertTrue(root.actionsView.isHidden)
        XCTAssertTrue(root.optionsButton.isHidden)
        XCTAssertTrue(root.addressCopyableLabel.isHidden)
        let allNetworks = R.string.localizable.chainSelectionAllNetworks(preferredLanguages: root.locale.rLanguages)
        XCTAssertTrue(CovHChainAccountViewInspector.texts(in: root).contains(allNetworks))
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCTAssertGreaterThan(controller.preferredContentHeight, 0)
        } else {
            XCTAssertEqual(controller.preferredContentHeight, 100)
        }
    }

    func testBalanceBindingShowsValuesTitleAndLockInfo() {
        let (controller, _, _) = makeController(mode: .extended)
        let transferable = LocalizableResource<BalanceViewModelProtocol> { _ in BalanceViewModel(amount: "12 COV", price: "$3") }
        let locked = LocalizableResource<BalanceViewModelProtocol> { _ in BalanceViewModel(amount: "2 COV", price: nil) }
        controller.didReceive(balanceViewModel: ChainAccountBalanceViewModel(
            transferrableValue: transferable, lockedValue: locked, hasLockedTokens: true,
            lockedTitle: LocalizableResource { _ in "Pending" }
        ))
        let root = controller.rootView
        XCTAssertEqual(root.transferableBalanceView.valueTop.text, "12 COV")
        XCTAssertEqual(root.balanceLocksView.valueTop.text, "2 COV")
        XCTAssertEqual(root.balanceLocksView.titleLabel.text, "Pending")
        XCTAssertFalse(root.infoButton.isHidden)

        controller.didReceive(balanceViewModel: nil)
        XCTAssertTrue(root.infoButton.isHidden)
        XCTAssertEqual(
            root.balanceLocksView.titleLabel.text,
            R.string.localizable.walletBalanceLocked(preferredLanguages: root.locale.rLanguages)
        )
    }

    func testLocalizationContainableAndSizing() {
        let (controller, _, _) = makeController(mode: .extended)
        controller.applyLocalization()
        let root = controller.rootView
        XCTAssertEqual(root.sendButton.title(for: .normal), R.string.localizable.walletSendTitle(preferredLanguages: root.locale.rLanguages))
        XCTAssertTrue(controller.contentView === controller.view)
        controller.setContentInsets(UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1), animated: false)
        XCTAssertEqual(controller.contentInsets, .zero)
        XCTAssertGreaterThan(controller.preferredContentHeight, 0)
        XCTAssertGreaterThan(root.fittingContentHeight, 0)
    }

    func testFactoryAssemblesTheModule() throws {
        let chainAsset = CovHChainAccountFixture.chainAsset()
        let output = CovHChainAccountModuleOutputSpy()
        let module = try XCTUnwrap(ChainAccountViewFactory.createView(
            chainAsset: chainAsset, wallet: CovHChainAccountFixture.wallet(), moduleOutput: output, mode: .extended
        ))
        let controller = try XCTUnwrap(module.view?.controller as? ChainAccountViewController)
        let presenter = try XCTUnwrap(controller.presenter as? ChainAccountPresenter)
        let input = try XCTUnwrap(module.moduleInput)
        XCTAssertTrue(input === presenter)
        XCTAssertTrue(presenter.view === controller)
        XCTAssertEqual(presenter.mode, .extended)
        XCTAssertEqual(presenter.chainAsset.chain.chainId, chainAsset.chain.chainId)
    }
}
