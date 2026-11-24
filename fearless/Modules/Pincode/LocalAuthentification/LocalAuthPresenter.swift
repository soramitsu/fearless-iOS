import Foundation
import SoraKeystore

class LocalAuthPresenter: PinSetupPresenterProtocol {
    private weak var view: PinSetupViewProtocol?
    private let wireframe: PinSetupWireframeProtocol
    private let interactor: LocalAuthInteractorInputProtocol
    private let lockState: ApplicationLockState
    /// The lock generation in which the interactor's current attempt (biometry or a PIN check) began. Set only when
    /// the interactor reports it started one, never for input it may ignore.
    private var authenticationGeneration: UInt64

    init(
        wireframe: PinSetupWireframeProtocol,
        interactor: LocalAuthInteractorInputProtocol,
        lockState: ApplicationLockState = .shared
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.lockState = lockState
        authenticationGeneration = lockState.generation
    }

    func didLoad(view: PinSetupViewProtocol) {
        self.view = view

        self.view?.didChangeAccessoryState(
            enabled: interactor.allowManualBiometryAuth,
            availableBiometryType: interactor.availableBiometryType
        )
        interactor.startAuth(with: self)
    }

    func cancel() {}

    func activateBiometricAuth() {
        interactor.startAuth(with: self)
    }

    func submit(pin: String) {
        interactor.process(pin: pin)
    }

    /// A new lock adopted this PIN screen while it was on screen: any attempt in flight is dropped and the PIN asks
    /// again, as for a newly shown lock.
    func restartAuthentication() {
        authenticationGeneration = lockState.generation
        interactor.cancelAuth()
        view?.didStopLoading()
        view?.resetAuthenticationInput()
        interactor.startAuth(with: self)
    }
}

extension LocalAuthPresenter: LocalAuthInteractorOutputProtocol {
    func didEnterWrongPincode() {
        DispatchQueue.main.async { [weak self] in
            self?.view?.didStopLoading()
            self?.view?.didReceiveWrongPincode()
        }
    }

    func didReceiveLockout(remaining: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            self?.view?.didStopLoading()
            self?.view?.didReceiveLockout(remaining: remaining)
        }
    }

    func didChangeState(to state: LocalAuthInteractor.LocalAuthState) {
        switch state {
        case .checkingBiometry, .checkingPincode:
            // The interactor accepted an attempt: it belongs to the lock that is due now.
            authenticationGeneration = lockState.generation
        case .completed:
            view?.didStartLoading()
        case .waitingPincode, .unexpectedFail:
            break
        }
    }

    func didCompleteAuth() {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            guard strongSelf.lockState.generation == strongSelf.authenticationGeneration else {
                // Began before a newer lock became due (for example a success queued across a long absence): it
                // does not end that lock. Ask again.
                strongSelf.restartAuthentication()
                return
            }
            strongSelf.wireframe.showMain(from: strongSelf.view)
        }
    }

    func didUnexpectedFail() {
        DispatchQueue.main.async { [weak self] in
            self?.wireframe.showSignup(from: self?.view)
        }
    }
}
