import Foundation
import SoraKeystore

class PinSetupPresenter: PinSetupPresenterProtocol {
    private weak var view: PinSetupViewProtocol?
    private var interactor: PinSetupInteractorInputProtocol
    private var wireframe: PinSetupWireframeProtocol
    private let userDefaultsStorage: SettingsManagerProtocol

    init(
        interactor: PinSetupInteractorInputProtocol,
        wireframe: PinSetupWireframeProtocol,
        userDefaultsStorage: SettingsManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.userDefaultsStorage = userDefaultsStorage
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
            if self?.userDefaultsStorage.bool(for: EducationStoriesKeys.newsVersion2.rawValue) == nil {
                self?.wireframe.showStories()
            } else {
                self?.wireframe.showMain(from: self?.view)
            }
        }
    }

    func didChangeState(from _: PinSetupInteractor.PinSetupState) {}
}
