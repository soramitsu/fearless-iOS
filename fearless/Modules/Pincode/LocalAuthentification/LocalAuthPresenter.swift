import Foundation
import SoraKeystore

class LocalAuthPresenter: PinSetupPresenterProtocol {
    private weak var view: PinSetupViewProtocol?
    private let wireframe: PinSetupWireframeProtocol
    private let interactor: LocalAuthInteractorInputProtocol
    private let userDefaultsStorage: SettingsManagerProtocol

    private var isNeedShowStories: Bool {
        get {
            userDefaultsStorage.bool(
                for: EducationStoriesKeys.isNeedShowNewsVersion2.rawValue
            ) ?? true
        }
        set {
            userDefaultsStorage.set(
                value: newValue,
                for: EducationStoriesKeys.isNeedShowNewsVersion2.rawValue
            )
        }
    }

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
            guard let strongSelf = self else { return }
            strongSelf.isNeedShowStories = false
            strongSelf.wireframe.showMain(from: strongSelf.view)
        }
    }

    func didUnexpectedFail() {
        DispatchQueue.main.async { [weak self] in
            self?.wireframe.showSignup(from: self?.view)
        }
    }
}
