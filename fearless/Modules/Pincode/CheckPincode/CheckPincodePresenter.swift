import Foundation

class CheckPincodePresenter: PinSetupPresenterProtocol {
    private weak var view: PinSetupViewProtocol?
    private let interactor: LocalAuthInteractorInputProtocol
    private let moduleOutput: CheckPincodeModuleOutput

    init(
        interactor: LocalAuthInteractorInputProtocol,
        moduleOutput: CheckPincodeModuleOutput
    ) {
        self.interactor = interactor
        self.moduleOutput = moduleOutput
    }

    func didLoad(view: PinSetupViewProtocol) {
        self.view = view

        self.view?.didChangeAccessoryState(
            enabled: interactor.allowManualBiometryAuth,
            availableBiometryType: interactor.availableBiometryType
        )
        interactor.startAuth(with: self)
    }

    func cancel() {
        moduleOutput.close(view: view)
    }

    func activateBiometricAuth() {
        interactor.startAuth(with: self)
    }

    func submit(pin: String) {
        interactor.process(pin: pin)
    }
}

extension CheckPincodePresenter: LocalAuthInteractorOutputProtocol {
    func didEnterWrongPincode() {
        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceiveWrongPincode()
        }
    }

    func didChangeState(to _: LocalAuthInteractor.LocalAuthState) {}

    func didCompleteAuth() {
        DispatchQueue.main.async { [weak self] in
            self?.moduleOutput.didCheck()
        }
    }

    func didUnexpectedFail() {}
}
