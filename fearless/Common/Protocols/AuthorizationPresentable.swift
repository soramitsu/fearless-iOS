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
