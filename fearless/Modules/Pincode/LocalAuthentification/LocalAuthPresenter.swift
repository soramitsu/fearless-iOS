import Foundation
import SoraKeystore

class LocalAuthPresenter: PinSetupPresenterProtocol {
    private weak var view: PinSetupViewProtocol?
    private let wireframe: PinSetupWireframeProtocol
    private let interactor: LocalAuthInteractorInputProtocol
    private let userDefaultsStorage: SettingsManagerProtocol

    init(
        wireframe: PinSetupWireframeProtocol,
        interactor: LocalAuthInteractorInputProtocol,
        userDefaultsStorage: SettingsManagerProtocol
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.userDefaultsStorage = userDefaultsStorage
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
            self?.view?.didReceiveWrongPincode()
        }
    }

    func didChangeState(from _: LocalAuthInteractor.LocalAuthState) {}

    func didCompleteAuth() {
        DispatchQueue.main.async { [weak self] in
            if self?.userDefaultsStorage.bool(for: EducationStoriesKeys.newsVersion2.rawValue) == nil {
                self?.wireframe.showStories()
            } else {
                self?.wireframe.showMain(from: self?.view)
            }
        }
    }

    func didUnexpectedFail() {
        DispatchQueue.main.async { [weak self] in
            self?.wireframe.showSignup(from: self?.view)
        }
    }
}
