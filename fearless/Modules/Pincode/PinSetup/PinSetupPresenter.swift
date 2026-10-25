import Foundation
import SoraKeystore

class PinSetupPresenter: PinSetupPresenterProtocol {
    private weak var view: PinSetupViewProtocol?
    private var interactor: PinSetupInteractorInputProtocol
    private var wireframe: PinSetupWireframeProtocol
    private var completed = false

    init(
        interactor: PinSetupInteractorInputProtocol,
        wireframe: PinSetupWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }

    deinit { interactor.cancel() }

    func didLoad(view: PinSetupViewProtocol) {
        self.view = view

        self.view?.didChangeAccessoryState(enabled: false, availableBiometryType: .none)
    }

    func activateBiometricAuth() {}

    func cancel() {
        guard !completed else { return }
        completed = true
        interactor.cancel()
        view?.didStopLoading()
    }

    func submit(pin: String) {
        guard !completed else { return }
        interactor.process(pin: pin)
    }
}

extension PinSetupPresenter: PinSetupInteractorOutputProtocol {
    func didStartWaitingBiometryDecision(
        type: AvailableBiometryType,
        completionBlock: @escaping (Bool) -> Void
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.completed else { return }
            self.view?.didRequestBiometryUsage(biometryType: type, completionBlock: completionBlock)
        }
    }

    func didSavePin() {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self, !strongSelf.completed else { return }
            strongSelf.completed = true
            strongSelf.view?.didStopLoading()
            strongSelf.wireframe.showMain(from: strongSelf.view)
        }
    }

    func didChangeState(to state: PinSetupInteractor.PinSetupState) {
        guard !completed else { return }
        switch state {
        case .submitingPincode:
            view?.didStartLoading()
        case .saveFailed:
            view?.didStopLoading()
            view?.didFailSavingPin()
        default:
            break
        }
    }
}
