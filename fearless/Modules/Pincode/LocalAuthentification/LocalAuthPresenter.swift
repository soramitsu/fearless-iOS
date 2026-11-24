import Foundation
import SoraKeystore

class LocalAuthPresenter: PinSetupPresenterProtocol {
    private weak var view: PinSetupViewProtocol?
    private let wireframe: PinSetupWireframeProtocol
    private let interactor: LocalAuthInteractorInputProtocol
    private let lockState: ApplicationLockState
    /// The lock generation in which the current authentication began.
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
        authenticationGeneration = lockState.generation

        self.view?.didChangeAccessoryState(
            enabled: interactor.allowManualBiometryAuth,
            availableBiometryType: interactor.availableBiometryType
        )
        interactor.startAuth(with: self)
    }

    func cancel() {}

    func activateBiometricAuth() {
        authenticationGeneration = lockState.generation
        interactor.startAuth(with: self)
    }

    func submit(pin: String) {
        authenticationGeneration = lockState.generation
        interactor.process(pin: pin)
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
        guard case .completed = state else {
            return
        }
        view?.didStartLoading()
    }

    func didCompleteAuth() {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            guard strongSelf.lockState.generation == strongSelf.authenticationGeneration else {
                // Began before a newer lock became due (for example a success queued across a long absence): it
                // does not end that lock. Ask again.
                strongSelf.authenticationGeneration = strongSelf.lockState.generation
                strongSelf.interactor.cancelAuth()
                strongSelf.view?.didStopLoading()
                strongSelf.view?.resetAuthenticationInput()
                strongSelf.interactor.startAuth(with: strongSelf)
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
