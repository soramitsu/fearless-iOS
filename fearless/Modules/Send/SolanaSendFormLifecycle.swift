import UIKit

protocol SolanaSendFormViewState: AnyObject {
    var allowsSendFormContinuation: Bool { get }
}

/// UIKit custom sheets can cover the form without a disappearance callback. Presentation
/// and live visibility checks complement lifecycle revocation; only a fresh action resumes.
final class SolanaSendFormLifecycle: NSObject {
    private weak var controller: UIViewController?
    private weak var scope: SolanaSendFormScopeManaging?
    private weak var inactiveScene: UIScene?
    private var applicationIsActive = UIApplication.shared.applicationState == .active

    init(controller: UIViewController, scope: SolanaSendFormScopeManaging?) {
        self.controller = controller
        self.scope = scope
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didEnterBackground),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        let inactiveNotifications = [
            UIScene.willDeactivateNotification, UIScene.didEnterBackgroundNotification,
            UIScene.didDisconnectNotification
        ]
        for name in inactiveNotifications {
            NotificationCenter.default.addObserver(
                self, selector: #selector(sceneBecameInactive(_:)), name: name, object: nil
            )
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(sceneBecameActive(_:)), name: UIScene.didActivateNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var isAvailable: Bool {
        guard applicationIsActive, let controller, controller.viewIfLoaded?.window != nil,
              !controller.isBeingDismissed, !controller.isMovingFromParent else { return false }
        guard let scene = controller.viewIfLoaded?.window?.windowScene,
              scene !== inactiveScene, scene.activationState == .foregroundActive else { return false }
        let navigation = controller.navigationController
        guard navigation?.isBeingDismissed != true,
              navigation == nil || navigation?.topViewController === controller else { return false }
        guard let presented = controller.presentedViewController else { return true }
        return owns(presented)
    }

    func resumeIfAvailable() {
        if isAvailable { scope?.resumeSendForm() } else { scope?.suspendSendForm() }
    }

    func willPresent(_ presented: UIViewController) {
        if !owns(presented) { scope?.suspendSendForm() }
    }

    func willDisappear() {
        guard let controller else { return }
        let navigation = controller.navigationController
        let navigatedAway = controller.isMovingFromParent || controller.isBeingDismissed ||
            navigation?.isBeingDismissed == true ||
            (navigation != nil && navigation?.topViewController !== controller)
        let ownedSheet = controller.presentedViewController.map(owns) ?? false
        if navigatedAway || !ownedSheet { scope?.suspendSendForm() }
    }

    private func owns(_ presented: UIViewController) -> Bool {
        guard let sheet = presented as? SheetAletViewController else { return false }
        return scope?.ownsSendFormPresentation(sheet.presentationID) == true
    }

    @objc private func sceneBecameInactive(_ notification: Notification) {
        guard let scene = notification.object as? UIScene,
              scene === controller?.viewIfLoaded?.window?.windowScene else { return }
        inactiveScene = scene
        scope?.suspendSendForm()
    }

    @objc private func sceneBecameActive(_ notification: Notification) {
        guard let scene = notification.object as? UIScene,
              scene === controller?.viewIfLoaded?.window?.windowScene else { return }
        if inactiveScene === scene { inactiveScene = nil }
        resumeIfAvailable()
    }

    @objc private func didEnterBackground() {
        applicationIsActive = false
        scope?.suspendSendForm()
    }

    @objc private func didBecomeActive() {
        applicationIsActive = true
        resumeIfAvailable()
    }
}
