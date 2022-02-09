import Foundation

class CheckPincodePresenter: PinSetupPresenterProtocol {
    weak var view: PinSetupViewProtocol?
    let interactor: LocalAuthInteractorInputProtocol
    let moduleOutput: CheckPincodeModuleOutput

    init(
        interactor: LocalAuthInteractorInputProtocol,
        moduleOutput: CheckPincodeModuleOutput
    ) {
        self.interactor = interactor
        self.moduleOutput = moduleOutput
    }

    func start() {
        view?.didChangeAccessoryState(
            enabled: interactor.allowManualBiometryAuth,
            availableBiometryType: interactor.availableBiometryType
        )
        interactor.startAuth()
    }

    func cancel() {}

    func activateBiometricAuth() {
        interactor.startAuth()
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

    func didChangeState(from _: LocalAuthInteractor.LocalAuthState) {}

    func didCompleteAuth() {
        DispatchQueue.main.async { [weak self] in
            self?.moduleOutput.didCheck()
        }
    }

    func didUnexpectedFail() {}
}
