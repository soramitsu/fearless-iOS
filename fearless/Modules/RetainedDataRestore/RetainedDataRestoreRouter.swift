import LocalAuthentication
import SoraKeystore
import UIKit

/// Shared only to retain the PIN authorization delegate until dismissal.
final class RetainedDataRestoreRouter: AuthorizationPresentable {
    static let shared = RetainedDataRestoreRouter()
    private var isAuthenticating = false

    func authorizeRecovery(from view: ControllerBackedProtocol, completion: @escaping (Bool) -> Void) {
        guard !isAuthenticating else { completion(false); return }
        isAuthenticating = true
        let finish: (Bool) -> Void = { [weak self] granted in
            self?.isAuthenticating = false
            completion(granted)
        }
        do {
            if try Keychain().checkKey(for: KeystoreTag.pincode.rawValue) {
                authorize(animated: true, cancellable: true, from: view, with: finish)
            } else {
                // Historical installations may predate an app PIN. Require the
                // device owner's existing passcode/biometrics, never a newly set PIN.
                let context = LAContext()
                context.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: RecoveryText.string("authenticate")
                ) { success, _ in
                    DispatchQueue.main.async { finish(success) }
                }
            }
        } catch {
            finish(false)
        }
    }

    func showEmergencyMaterial(from view: ControllerBackedProtocol?) {
        guard let view else { return }
        let access = EmergencyWalletMaterialAccess(reader: EmergencyWalletMaterialReader())
        access.read(authorize: { completion in
            self.authorizeRecovery(from: view, completion: completion)
        }, completion: { [weak view] result in
            guard let view, let result else { return }
            switch result {
            case let .success(material):
                let controller = EmergencyWalletMaterialViewController(material: material)
                let navigation = FearlessNavigationController(rootViewController: controller)
                navigation.modalPresentationStyle = .fullScreen
                view.controller.present(navigation, animated: true)
            case .failure:
                self.showMessage(RecoveryText.string("read_failed"), from: view.controller)
            }
        })
    }

    func showPreviousData(from view: ControllerBackedProtocol?) {
        guard let view else { return }
        authorizeRecovery(from: view) { [weak view] granted in
            guard granted, let view else { return }
            let controller = RetainedDataRestoreAssembly.createView()
            let navigation = FearlessNavigationController(rootViewController: controller)
            view.controller.present(navigation, animated: true)
        }
    }

    func showMessage(_ message: String, from controller: UIViewController) {
        let alert = UIAlertController(title: RecoveryText.string("title"), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: RecoveryText.string("close"), style: .cancel))
        controller.present(alert, animated: true)
    }
}
