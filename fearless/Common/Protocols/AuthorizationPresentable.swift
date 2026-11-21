import UIKit

typealias AuthorizationCompletionBlock = (Bool) -> Void

protocol AuthorizationPresentable: ScreenAuthorizationWireframeProtocol {
    func createAuthorizationView(
        with wireframe: ScreenAuthorizationWireframeProtocol,
        cancellable: Bool
    ) -> PinSetupViewProtocol?

    func authorize(
        animated: Bool,
        cancellable: Bool,
        from view: ControllerBackedProtocol?,
        with completionBlock: @escaping AuthorizationCompletionBlock
    )
}

protocol AuthorizationAccessible {
    var isAuthorizing: Bool { get }
}

private enum AuthorizationConstants {
    static var completionBlockKey: UInt8 = 0
    static var authorizationViewKey: UInt8 = 0
}

extension AuthorizationAccessible {
    var isAuthorizing: Bool {
        let view = objc_getAssociatedObject(
            self,
            &AuthorizationConstants.authorizationViewKey
        )
            as? PinSetupViewProtocol

        return view != nil
    }
}

extension AuthorizationPresentable {
    private var completionBlock: AuthorizationCompletionBlock? {
        get {
            objc_getAssociatedObject(self, &AuthorizationConstants.completionBlockKey)
                as? AuthorizationCompletionBlock
        }

        set {
            objc_setAssociatedObject(
                self,
                &AuthorizationConstants.completionBlockKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN
            )
        }
    }

    private var authorizationView: PinSetupViewProtocol? {
        get {
            objc_getAssociatedObject(self, &AuthorizationConstants.authorizationViewKey)
                as? PinSetupViewProtocol
        }

        set {
            objc_setAssociatedObject(
                self,
                &AuthorizationConstants.authorizationViewKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN
            )
        }
    }

    private var isAuthorizing: Bool {
        authorizationView != nil
    }
}

extension AuthorizationPresentable {
    func createAuthorizationView(
        with wireframe: ScreenAuthorizationWireframeProtocol,
        cancellable: Bool
    ) -> PinSetupViewProtocol? {
        PinViewFactory.createScreenAuthorizationView(with: wireframe, cancellable: cancellable)
    }

    func authorize(animated: Bool, with completionBlock: @escaping AuthorizationCompletionBlock) {
        authorize(animated: animated, cancellable: false, with: completionBlock)
    }

    func authorize(
        animated: Bool,
        cancellable: Bool,
        with completionBlock: @escaping AuthorizationCompletionBlock
    ) {
        authorize(
            animated: animated,
            cancellable: cancellable,
            from: nil,
            with: completionBlock
        )
    }

    func authorize(
        animated: Bool,
        cancellable: Bool,
        from view: ControllerBackedProtocol? = nil,
        with completionBlock: @escaping AuthorizationCompletionBlock
    ) {
        guard !isAuthorizing else {
            return
        }

        guard let presentingController = view?.controller else {
            return
        }

        guard let authorizationView = createAuthorizationView(
            with: self,
            cancellable: cancellable
        ) else {
            completionBlock(false)
            return
        }

        self.completionBlock = completionBlock
        self.authorizationView = authorizationView

        authorizationView.controller.modalTransitionStyle = .crossDissolve
        authorizationView.controller.modalPresentationStyle = .fullScreen
        presentingController.present(authorizationView.controller, animated: animated, completion: nil)
    }
}

/// Asks for the PIN, or a biometric the PIN holder trusted, immediately before an operation that moves funds or
/// changes staking. A cancelled or failed authorization reports `false`: the caller then submits nothing and leaves
/// its confirm screen as it was.
protocol SubmissionAuthorizing: AnyObject {
    func authorizeSubmission(from view: ControllerBackedProtocol?, completion: @escaping (Bool) -> Void)
}

extension SubmissionAuthorizing {
    /// Runs `action` only after a fresh successful authorization.
    func performAuthorized(from view: ControllerBackedProtocol?, _ action: @escaping () -> Void) {
        authorizeSubmission(from: view) { authorized in
            if authorized {
                action()
            }
        }
    }
}

/// Presents the screen-authorization module (PIN pad with the trusted-biometric prompt) over the confirm screen.
/// Each confirm screen owns one instance.
final class SubmissionAuthorizer: SubmissionAuthorizing, AuthorizationPresentable {
    private final class PresentingHost: ControllerBackedProtocol {
        let controller: UIViewController
        var isSetup: Bool { controller.isViewLoaded }

        init(controller: UIViewController) {
            self.controller = controller
        }
    }

    private static let presentationRetries = 20
    private static let retryInterval: TimeInterval = 0.1

    private let viewFactory: (ScreenAuthorizationWireframeProtocol) -> PinSetupViewProtocol?
    private var pendingCompletion: ((Bool) -> Void)?

    init(
        viewFactory: @escaping (ScreenAuthorizationWireframeProtocol) -> PinSetupViewProtocol? = {
            PinViewFactory.createScreenAuthorizationView(with: $0, cancellable: true)
        }
    ) {
        self.viewFactory = viewFactory
    }

    func createAuthorizationView(
        with wireframe: ScreenAuthorizationWireframeProtocol,
        cancellable _: Bool
    ) -> PinSetupViewProtocol? {
        viewFactory(wireframe)
    }

    func authorizeSubmission(from view: ControllerBackedProtocol?, completion: @escaping (Bool) -> Void) {
        guard pendingCompletion == nil, let source = view?.controller else {
            completion(false)
            return
        }
        pendingCompletion = completion
        present(from: source, retriesLeft: Self.presentationRetries)
    }

    private func present(from source: UIViewController, retriesLeft: Int) {
        guard source.viewIfLoaded?.window != nil else {
            finish(false)
            return
        }
        var host = source
        while let presented = host.presentedViewController, !presented.isBeingDismissed {
            host = presented
        }
        // UIKit drops a presentation started while another one is still moving, which would strand Confirm.
        guard host.presentedViewController == nil, host.transitionCoordinator == nil, !host.isBeingPresented else {
            guard retriesLeft > 0 else {
                finish(false)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.retryInterval) { [weak self, weak source] in
                guard let self = self else { return }
                guard let source = source else {
                    self.finish(false)
                    return
                }
                self.present(from: source, retriesLeft: retriesLeft - 1)
            }
            return
        }
        authorize(animated: true, cancellable: true, from: PresentingHost(controller: host)) { [weak self] result in
            self?.finish(result)
        }
        // A presentation UIKit refused never calls back: release the request so Confirm stays usable.
        if pendingCompletion != nil, host.presentedViewController == nil {
            showAuthorizationCompletion(with: false)
        }
    }

    private func finish(_ result: Bool) {
        let completion = pendingCompletion
        pendingCompletion = nil
        completion?(result)
    }
}

extension AuthorizationPresentable {
    func showAuthorizationCompletion(with result: Bool) {
        guard let completionBlock, let authorizationView else {
            self.completionBlock = nil
            self.authorizationView = nil
            return
        }
        self.completionBlock = nil
        let controller = authorizationView.controller
        let complete = { [weak self, weak controller] in
            guard let self, let controller, self.authorizationView?.controller === controller else { return }
            self.authorizationView = nil
            completionBlock(result)
        }
        if controller.isBeingDismissed {
            if let coordinator = controller.transitionCoordinator,
               coordinator.animate(alongsideTransition: nil, completion: { _ in complete() }) {
                return
            }
            DispatchQueue.main.async(execute: complete)
        } else if let presentingController = controller.presentingViewController {
            presentingController.dismiss(animated: true, completion: complete)
        } else {
            complete()
        }
    }
}
