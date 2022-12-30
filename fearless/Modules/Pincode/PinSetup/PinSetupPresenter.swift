import Foundation
import SoraKeystore

class PinSetupPresenter: PinSetupPresenterProtocol {
    private weak var view: PinSetupViewProtocol?
    private var interactor: PinSetupInteractorInputProtocol
    private var wireframe: PinSetupWireframeProtocol

    init(
        interactor: PinSetupInteractorInputProtocol,
        wireframe: PinSetupWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }

    func didLoad(view: PinSetupViewProtocol) {
        self.view = view

        self.view?.didChangeAccessoryState(enabled: false, availableBiometryType: .none)
    }

    func activateBiometricAuth() {}

    func cancel() {}

    func submit(pin: String) {
        interactor.process(pin: pin)
    }
}

extension PinSetupPresenter: PinSetupInteractorOutputProtocol {
    func didStartWaitingBiometryDecision(
        type: AvailableBiometryType,
        completionBlock: @escaping (Bool) -> Void
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.view?.didRequestBiometryUsage(biometryType: type, completionBlock: completionBlock)
        }
    }

    func didSavePin() {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.wireframe.showMain(from: strongSelf.view)
        }
    }

    func didChangeState(to state: PinSetupInteractor.PinSetupState) {
        guard case .submitedPincode = state else {
            return
        }
        view?.didStartLoading()
    }
}
