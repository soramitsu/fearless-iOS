import Foundation

final class ScreenAuthorizationPresenter {
    private weak var view: PinSetupViewProtocol?
    private var wireframe: ScreenAuthorizationWireframeProtocol
    private var interactor: LocalAuthInteractorInputProtocol

    init(
        wireframe: ScreenAuthorizationWireframeProtocol,
        interactor: LocalAuthInteractorInputProtocol
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
    }
}

extension ScreenAuthorizationPresenter: PinSetupPresenterProtocol {
    func didLoad(view: PinSetupViewProtocol) {
        self.view = view

        self.view?.didChangeAccessoryState(
            enabled: interactor.allowManualBiometryAuth,
            availableBiometryType: interactor.availableBiometryType
        )
        interactor.startAuth(with: self)
    }

    func cancel() {
        wireframe.showAuthorizationCompletion(with: false)
    }

    func activateBiometricAuth() {
        interactor.startAuth(with: self)
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
