import Foundation
import SoraKeystore

class LocalAuthPresenter: PinSetupPresenterProtocol {
    private weak var view: PinSetupViewProtocol?
    private let wireframe: PinSetupWireframeProtocol
    private let interactor: LocalAuthInteractorInputProtocol

    init(
        wireframe: PinSetupWireframeProtocol,
        interactor: LocalAuthInteractorInputProtocol
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
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
}

extension LocalAuthPresenter: LocalAuthInteractorOutputProtocol {
    func didEnterWrongPincode() {
        DispatchQueue.main.async { [weak self] in
            self?.view?.didStopLoading()
            self?.view?.didReceiveWrongPincode()
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
            strongSelf.wireframe.showMain(from: strongSelf.view)
        }
    }

    func didUnexpectedFail() {
        DispatchQueue.main.async { [weak self] in
            self?.wireframe.showSignup(from: self?.view)
        }
    }
}
