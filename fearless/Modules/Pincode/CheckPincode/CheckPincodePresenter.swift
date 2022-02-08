import Foundation

class CheckPincodePresenter: PinSetupPresenterProtocol {
    weak var view: PinSetupViewProtocol?
    let wireframe: CheckPincodeWireframeProtocol
    let interactor: LocalAuthInteractorInputProtocol
    let moduleOutput: CheckPincodeModuleOutput

    init(
        wireframe: CheckPincodeWireframeProtocol,
        interactor: LocalAuthInteractorInputProtocol,
        moduleOutput: CheckPincodeModuleOutput
    ) {
        self.wireframe = wireframe
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
            self?.wireframe.finishCheck(from: self?.view)
            self?.moduleOutput.didCheck()
        }
    }

    func didUnexpectedFail() {}
}
