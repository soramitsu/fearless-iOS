import Foundation
import SoraKeystore
import SoraUI
import SSFModels
import SSFUtils

final class WalletConnectConfirmationRouter: WalletConnectConfirmationRouterInput {
    func showAllDone(
        chain: ChainModel,
        hashString: String?,
        view: ControllerBackedProtocol?,
        closure: @escaping () -> Void
    ) {
        let module = AllDoneAssembly.configureModule(
            chainAsset: chain.chainAssets.first,
            hashString: hashString,
            closure: closure,
            isWalletConnectResult: true
        )
        guard let controller = module?.view.controller else {
            return
        }
        controller.modalPresentationStyle = .custom
        let factory = ModalSheetBlurPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.fearlessBlur
        )
        controller.modalTransitioningFactory = factory

        view?.controller.present(controller, animated: true)
    }

    func showRawData(json: JSON, from view: ControllerBackedProtocol?) {
        let module = RawDataAssembly.configureModule(json: json)
        guard let controller = module?.view.controller else {
            return
        }
        view?.controller.present(controller, animated: true)
    }
}

/// Asks for the PIN or biometrics before a WalletConnect request is signed.
protocol WalletConnectSigningAuthorizing: AnyObject {
    /// `false` when the user cancels or the PIN screen cannot be shown.
    func authorize() async -> Bool
}

/// Asks for the PIN or trusted biometrics through `SubmissionAuthorizer`, the step every fund-moving and staking
/// submission takes, so a signature for an app gets the same PIN lockout and biometric rules.
final class WalletConnectSigningAuthorizer: WalletConnectSigningAuthorizing {
    weak var view: ControllerBackedProtocol?

    /// True while the PIN screen asks; a second request waits for it to finish and is refused meanwhile.
    private(set) var isAuthorizing = false

    private let keystore: KeystoreProtocol
    private let submissionAuthorizer: SubmissionAuthorizing

    init(
        keystore: KeystoreProtocol = Keychain(),
        submissionAuthorizer: SubmissionAuthorizing = SubmissionAuthorizer()
    ) {
        self.keystore = keystore
        self.submissionAuthorizer = submissionAuthorizer
    }

    @MainActor
    func authorize() async -> Bool {
        // Without a PIN there is nothing to confirm with, so nothing is signed.
        guard
            let view = view,
            !isAuthorizing,
            (try? keystore.checkKey(for: KeystoreTag.pincode.rawValue)) == true
        else {
            return false
        }

        isAuthorizing = true
        let authorized = await withCheckedContinuation { continuation in
            let answer = AuthorizationAnswer(continuation: continuation)
            submissionAuthorizer.authorizeSubmission(from: view) { isAuthorized in
                answer.resume(returning: isAuthorized)
            }
        }
        isAuthorizing = false
        return authorized
    }
}

/// Resumes the waiting signer exactly once. A PIN screen that goes away without an
/// answer counts as not authorized, so signing never waits forever.
private final class AuthorizationAnswer {
    private var continuation: CheckedContinuation<Bool, Never>?

    init(continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
    }

    deinit {
        continuation?.resume(returning: false)
    }

    func resume(returning isAuthorized: Bool) {
        continuation?.resume(returning: isAuthorized)
        continuation = nil
    }
}
