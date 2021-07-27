import Foundation

final class ScreenAuthorizationPresenter {
    weak var view: PinSetupViewProtocol?
    var wireframe: ScreenAuthorizationWireframeProtocol!
    var interactor: LocalAuthInteractorInputProtocol!
}

extension ScreenAuthorizationPresenter: PinSetupPresenterProtocol {
    func start() {
        view?.didChangeAccessoryState(
            enabled: interactor.allowManualBiometryAuth,
            availableBiometryType: interactor.availableBiometryType
        )
        interactor.startAuth()
    }

    func cancel() {
        wireframe.showAuthorizationCompletion(with: false)
    }

    func activateBiometricAuth() {
        interactor.startAuth()
    }

    func submit(pin: String) {
        interactor.process(pin: pin)
    }
}

extension ScreenAuthorizationPresenter: LocalAuthInteractorOutputProtocol {
    func didEnterWrongPincode() {
        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceiveWrongPincode()
        }
    }

    func didChangeState(from _: LocalAuthInteractor.LocalAuthState) {}

    func didCompleteAuth() {
        DispatchQueue.main.async { [weak self] in
            self?.wireframe.showAuthorizationCompletion(with: true)
        }
    }

    func didUnexpectedFail() {
        DispatchQueue.main.async { [weak self] in
            self?.wireframe.showAuthorizationCompletion(with: false)
        }
    }
}
