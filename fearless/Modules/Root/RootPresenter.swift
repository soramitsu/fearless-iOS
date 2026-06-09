import UIKit
import FearlessFoundation

final class RootPresenter {
    var view: ControllerBackedProtocol?
    var window: UIWindow!
    var wireframe: RootWireframeProtocol!
    var interactor: RootInteractorInputProtocol!

    private let startViewHelper: StartViewHelperProtocol
    private var loadTask: Task<Void, Never>?

    init(
        localizationManager: LocalizationManagerProtocol,
        startViewHelper: StartViewHelperProtocol
    ) {
        self.startViewHelper = startViewHelper
        self.localizationManager = localizationManager
    }

    deinit {
        loadTask?.cancel()
    }

    private func decideModuleSynchroniously(with onboardingConfig: OnboardingConfigWrapper?) {
        let startView = startViewHelper.startView(onboardingConfig: onboardingConfig)
        switch startView {
        case .pin:
            wireframe.showLocalAuthentication(on: window)
        case .pinSetup:
            wireframe.showPincodeSetup(on: window)
        case .login:
            wireframe.showMain(on: window)
        case .broken:
            wireframe.showBroken(on: window)
        case let .onboarding(config):
            wireframe.showOnboarding(on: window, with: config)
        }
    }
}

extension RootPresenter: RootPresenterProtocol {
    func loadOnLaunch() {
        wireframe.showSplash(splashView: view, on: window)

        interactor.setup(runMigrations: true)
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let onboardingConfig = try await interactor.fetchOnboardingConfig()
                DispatchQueue.main.async { [weak self] in
                    self?.decideModuleSynchroniously(with: onboardingConfig)
                }
            } catch {
                Logger.shared.error(error.localizedDescription)
                DispatchQueue.main.async { [weak self] in
                    self?.decideModuleSynchroniously(with: nil)
                }
            }
        }
    }

    func reload() {
        loadTask?.cancel()
        interactor.setup(runMigrations: false)

        DispatchQueue.main.async { [weak self] in
            self?.decideModuleSynchroniously(with: nil)
        }
    }
}

extension RootPresenter: RootInteractorOutputProtocol {}

extension RootPresenter: Localizable {
    func applyLocalization() {}
}
