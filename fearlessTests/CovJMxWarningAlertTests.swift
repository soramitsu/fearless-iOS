import XCTest
import UIKit
@testable import fearless

/// A hand-driven transition context: records completions instead of finishing a UIKit transition.
final class CovJMxTransitionContext: NSObject, UIViewControllerContextTransitioning {
    let containerView: UIView
    private let fromController: UIViewController?
    private let toController: UIViewController?
    private(set) var completions: [Bool] = []

    init(container: UIView, from: UIViewController?, to: UIViewController?) {
        containerView = container
        fromController = from
        toController = to
    }

    var isAnimated: Bool { true }
    var isInteractive: Bool { false }
    var transitionWasCancelled: Bool { false }
    var presentationStyle: UIModalPresentationStyle { .custom }
    var targetTransform: CGAffineTransform { .identity }

    func updateInteractiveTransition(_: CGFloat) {}
    func finishInteractiveTransition() {}
    func cancelInteractiveTransition() {}
    func pauseInteractiveTransition() {}
    func completeTransition(_ didComplete: Bool) { completions.append(didComplete) }

    func viewController(forKey key: UITransitionContextViewControllerKey) -> UIViewController? {
        if key == .from { return fromController }
        if key == .to { return toController }
        return nil
    }

    func view(forKey _: UITransitionContextViewKey) -> UIView? { nil }
    func initialFrame(for _: UIViewController) -> CGRect { containerView.bounds }
    func finalFrame(for _: UIViewController) -> CGRect { containerView.bounds }
}

/// Reports an iPhone environment whatever simulator runs the tests.
final class CovJMxPhoneContainer: UIView {
    override var traitCollection: UITraitCollection {
        UITraitCollection(traitsFrom: [super.traitCollection, UITraitCollection(userInterfaceIdiom: .phone)])
    }
}

/// Reports a regular-width iPad environment without needing an iPad simulator.
final class CovJMxPadContainer: UIView {
    override var traitCollection: UITraitCollection {
        UITraitCollection(traitsFrom: [
            super.traitCollection,
            UITraitCollection(userInterfaceIdiom: .pad),
            UITraitCollection(horizontalSizeClass: .regular)
        ])
    }
}

final class CovJMxWarningPresenterSpy: WarningAlertPresenterProtocol {
    var loads = 0
    var actions = 0
    var closes = 0
    func didLoad(view _: WarningAlertViewProtocol) { loads += 1 }
    func didTapActionButton() { actions += 1 }
    func didTapCloseButton() { closes += 1 }
}

final class CovJMxWarningViewSpy: UIViewController, WarningAlertViewProtocol {
    var configs: [WarningAlertConfig] = []
    func didReceive(config: WarningAlertConfig) { configs.append(config) }
}

final class CovJMxWarningWireframeSpy: WarningAlertWireframeProtocol {
    var dismissals = 0
    func dismiss(view _: ControllerBackedProtocol?) { dismissals += 1 }
}

final class CovJMxWarningAlertTests: XCTestCase {
    private let locale = Locale(identifier: "en")

    func testPredefinedConfigsUseLocalizedCopyAndBlockingFlags() {
        let languages = locale.rLanguages
        let connection = WarningAlertConfig.connectionProblemAlertConfig(with: locale)
        XCTAssertEqual(connection.title, R.string.localizable.connectionProblemsText(preferredLanguages: languages))
        XCTAssertEqual(connection.text, R.string.localizable.appVersionJsonLoadingFailed(preferredLanguages: languages))
        XCTAssertEqual(connection.buttonTitle, R.string.localizable.commonRetry(preferredLanguages: languages))
        XCTAssertTrue(connection.blocksUi)
        XCTAssertNotNil(connection.iconImage)

        let version = WarningAlertConfig.unsupportedAppVersionConfig(with: locale)
        XCTAssertEqual(version.title, R.string.localizable.updateNeededText(preferredLanguages: languages))
        XCTAssertEqual(version.text, R.string.localizable.appVersionUnsupportedText(preferredLanguages: languages))
        XCTAssertEqual(version.buttonTitle, R.string.localizable.commonUpdate(preferredLanguages: languages))
        XCTAssertTrue(version.blocksUi)

        let chain = WarningAlertConfig.unsupportedChainConfig(with: locale)
        XCTAssertEqual(chain.title, version.title)
        XCTAssertEqual(chain.text, R.string.localizable.chainUnsupportedText(preferredLanguages: languages))
        XCTAssertFalse(chain.blocksUi)
    }

    func testPresenterSendsConfigOnLoadAndRoutesButtons() {
        let wireframe = CovJMxWarningWireframeSpy()
        var handled = 0
        let config = WarningAlertConfig(title: "T", iconImage: nil, text: "Body", buttonTitle: "Go", blocksUi: false)
        let presenter = WarningAlertPresenter(
            interactor: WarningAlertInteractor(),
            wireframe: wireframe,
            alertConfig: config,
            buttonHandler: { handled += 1 }
        )
        let view = CovJMxWarningViewSpy()

        presenter.didLoad(view: view)
        presenter.didTapActionButton()
        presenter.didTapCloseButton()

        XCTAssertEqual(view.configs.map(\.title), ["T"])
        XCTAssertEqual(view.configs.map(\.text), ["Body"])
        XCTAssertTrue(presenter.view === view)
        XCTAssertEqual(handled, 1)
        XCTAssertEqual(wireframe.dismissals, 1)
    }

    func testFactoryWiresModuleAndControllerBindsAndForwardsTaps() throws {
        var handled = 0
        let config = WarningAlertConfig.unsupportedChainConfig(with: locale)
        let view = try XCTUnwrap(WarningAlertViewFactory.createView(alertConfig: config, buttonHandler: { handled += 1 }))
        let controller = try XCTUnwrap(view.controller as? WarningAlertViewController)
        XCTAssertEqual(controller.modalPresentationStyle, .custom)
        XCTAssertTrue(controller.transitioningDelegate === controller)

        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let layout = try XCTUnwrap(controller.view as? WarningAlertViewLayout)

        XCTAssertEqual(layout.titleLabel.text, config.title)
        XCTAssertEqual(layout.textLabel.text, config.text)
        XCTAssertEqual(layout.actionButton.imageWithTitleView?.title, config.buttonTitle)
        XCTAssertFalse(layout.closeButton.isHidden)

        layout.actionButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(handled, 1)

        controller.didReceive(config: WarningAlertConfig(title: "Blocked", iconImage: nil, text: nil, buttonTitle: nil, blocksUi: true))
        XCTAssertEqual(layout.titleLabel.text, "Blocked")
        XCTAssertTrue(layout.closeButton.isHidden)
    }

    func testControllerSuppliesItsOwnAnimatorsAndLaysOutAsACardOnIPad() throws {
        let presenter = CovJMxWarningPresenterSpy()
        let controller = WarningAlertViewController(presenter: presenter)
        controller.loadViewIfNeeded()
        XCTAssertEqual(presenter.loads, 1)

        let source = UIViewController()
        XCTAssertTrue(controller.animationController(forPresented: controller, presenting: source, source: source) is WarningAlertPresentAnimator)
        XCTAssertTrue(controller.animationController(forDismissed: controller) is WarningAlertDismissAnimator)

        let container = CovJMxPadContainer(frame: CGRect(x: 0, y: 0, width: 1024, height: 768))
        container.addSubview(controller.view)
        controller.viewWillLayoutSubviews()
        XCTAssertEqual(controller.view.layer.cornerRadius, AdaptiveLayout.sheetCornerRadius)
        XCTAssertTrue(controller.view.clipsToBounds)

        let layout = try XCTUnwrap(controller.view as? WarningAlertViewLayout)
        layout.closeButton.sendActions(for: .touchUpInside)
        layout.actionButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.closes, 1)
        XCTAssertEqual(presenter.actions, 1)
    }

    func testPresentAnimatorRaisesTheSheetFromTheBottomOnIPhone() throws {
        let container = CovJMxPhoneContainer(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let from = UIViewController()
        container.addSubview(from.view)
        let to = UIViewController()
        let context = CovJMxTransitionContext(container: container, from: from, to: to)
        let animator = WarningAlertPresentAnimator()

        XCTAssertEqual(animator.transitionDuration(using: context), 0.5)
        animator.animateTransition(using: context)

        XCTAssertTrue(to.view.superview === container)
        XCTAssertEqual(container.subviews.count, 3)
        XCTAssertTrue(container.subviews.firstIndex(of: to.view) == 1)
        let pins = container.constraints.filter { type(of: $0) == NSLayoutConstraint.self && $0.firstItem === to.view }
        XCTAssertEqual(Set(pins.map(\.firstAttribute.rawValue)), Set([NSLayoutConstraint.Attribute.centerX, .bottom, .width].map(\.rawValue)))
        XCTAssertEqual(container.frame, UIScreen.main.bounds)
        XCTAssertTrue(CovJWait.until(timeout: 3) { context.completions == [true] })
    }

    func testPresentAnimatorCentersACardOnRegularWidthIPad() throws {
        // Like the iPad layout tests, the trait-overriding container stays out of a window.
        let container = CovJMxPadContainer(frame: CGRect(x: 0, y: 0, width: 834, height: 1194))
        let to = UIViewController()
        let context = CovJMxTransitionContext(container: container, from: nil, to: to)

        WarningAlertPresentAnimator().animateTransition(using: context)

        XCTAssertTrue(to.view.superview === container)
        XCTAssertEqual(to.view.transform, .identity)
        XCTAssertEqual(to.view.layer.cornerRadius, AdaptiveLayout.sheetCornerRadius)
        let backdrop = try XCTUnwrap(container.subviews.first)
        XCTAssertFalse(backdrop === to.view)
        XCTAssertEqual(backdrop.backgroundColor, UIColor.black.withAlphaComponent(0.2))
        XCTAssertTrue(CovJWait.until(timeout: 3) { context.completions == [true] })
    }

    func testAnimatorsWithoutControllersDoNothing() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let phone = CovJMxTransitionContext(container: container, from: nil, to: UIViewController())
        WarningAlertPresentAnimator().animateTransition(using: phone)
        let pad = CovJMxTransitionContext(container: CovJMxPadContainer(), from: nil, to: nil)
        WarningAlertPresentAnimator().animateTransition(using: pad)
        let dismiss = CovJMxTransitionContext(container: container, from: nil, to: nil)
        WarningAlertDismissAnimator().animateTransition(using: dismiss)

        CovJWait.drain(0.2)
        XCTAssertTrue(phone.completions.isEmpty)
        XCTAssertTrue(pad.completions.isEmpty)
        XCTAssertTrue(dismiss.completions.isEmpty)
        XCTAssertTrue(container.subviews.isEmpty)
    }

    func testDismissAnimatorFadesTheSheetOut() throws {
        let window = try CovJViewFixture.host(UIViewController())
        defer { window.isHidden = true }
        let container = UIView(frame: window.bounds)
        window.addSubview(container)
        let from = UIViewController()
        container.addSubview(from.view)
        let context = CovJMxTransitionContext(container: container, from: from, to: nil)
        let animator = WarningAlertDismissAnimator()

        XCTAssertEqual(animator.transitionDuration(using: context), 0.1)
        animator.animateTransition(using: context)

        XCTAssertEqual(from.view.alpha, 0)
        XCTAssertTrue(CovJWait.until(timeout: 3) { context.completions == [true] })
    }

    func testPresentedAlertClosesThroughItsWireframe() throws {
        let root = UIViewController()
        let window = try CovJViewFixture.host(root)
        defer {
            root.presentedViewController?.dismiss(animated: false)
            window.isHidden = true
        }
        let config = WarningAlertConfig(title: "Notice", iconImage: nil, text: "Body", buttonTitle: "OK", blocksUi: false)
        let view = try XCTUnwrap(WarningAlertViewFactory.createView(alertConfig: config, buttonHandler: {}))

        root.present(view.controller, animated: true)
        XCTAssertTrue(CovJWait.until(timeout: 3) { root.presentedViewController === view.controller && !view.controller.isBeingPresented })

        let layout = try XCTUnwrap(view.controller.view as? WarningAlertViewLayout)
        layout.closeButton.sendActions(for: .touchUpInside)

        XCTAssertTrue(CovJWait.until(timeout: 3) { root.presentedViewController == nil })
    }
}
