import Foundation

class CheckPincodePresenter: PinSetupPresenterProtocol {
    private weak var view: PinSetupViewProtocol?
    private let interactor: LocalAuthInteractorInputProtocol
    private let moduleOutput: CheckPincodeModuleOutput
    private var finished = false

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
        guard !finished else { return }
        finished = true
        interactor.cancelAuth()
        moduleOutput.close(view: view)
    }

    func activateBiometricAuth() {
        guard !finished else { return }
        interactor.startAuth(with: self)
    }

    func submit(pin: String) {
        guard !finished else { return }
        interactor.process(pin: pin)
    }
}

extension CheckPincodePresenter: LocalAuthInteractorOutputProtocol {
    func didEnterWrongPincode() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.finished else { return }
            self.view?.didReceiveWrongPincode()
        }
    }

    func didChangeState(to _: LocalAuthInteractor.LocalAuthState) {}

    func didCompleteAuth() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.finished else { return }
            self.finished = true
            self.interactor.cancelAuth()
            self.moduleOutput.didCheck()
        }
    }

    func didUnexpectedFail() {}
}
