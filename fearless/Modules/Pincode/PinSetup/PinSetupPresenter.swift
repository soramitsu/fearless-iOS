import Foundation
import SoraKeystore

class PinSetupPresenter: PinSetupPresenterProtocol {
    private weak var view: PinSetupViewProtocol?
    private var interactor: PinSetupInteractorInputProtocol
    private var wireframe: PinSetupWireframeProtocol
    private let userDefaultsStorage: SettingsManagerProtocol

    private lazy var isNeedShowStories: Bool = {
        userDefaultsStorage.bool(
            for: EducationStoriesKeys.isNeedShowNewsVersion2.rawValue
        ) ?? true
    }()

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
            guard let strongSelf = self else { return }

            strongSelf.isNeedShowStories
                ? strongSelf.wireframe.showStories()
                : strongSelf.wireframe.showMain(from: strongSelf.view)
        }
    }

    func didChangeState(from _: PinSetupInteractor.PinSetupState) {}
}
