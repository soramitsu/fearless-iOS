import UIKit
import SoraFoundation

final class RootPresenter {
    var view: RootViewProtocol?
    var window: UIWindow!
    var wireframe: RootWireframeProtocol!
    var interactor: RootInteractorInputProtocol!

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }
}

extension RootPresenter: RootPresenterProtocol {
    func loadOnLaunch() {
        wireframe.showSplash(splashView: view, on: window)

        interactor.setup(runMigrations: true)
        interactor.checkAppVersion()
    }

    func reload() {
        interactor.setup(runMigrations: false)
        interactor.checkAppVersion()
    }

    func didTapRetryButton(from state: RootViewState) {
        view?.didReceive(state: .plain)

        switch state {
        case .plain:
            break
        case .retry:
            interactor.checkAppVersion()
        case .update:
            wireframe.showVersionUnsupported(from: view, locale: selectedLocale)
        }
    }
}

extension RootPresenter: RootInteractorOutputProtocol {
    func didDecideOnboarding() {
        wireframe.showOnboarding(on: window)
    }

    func didDecideLocalAuthentication() {
        wireframe.showLocalAuthentication(on: window)
    }

    func didDecidePincodeSetup() {
        wireframe.showPincodeSetup(on: window)
    }

    func didDecideBroken() {
        wireframe.showBroken(on: window)
    }

    func didDecideVersionUnsupported() {
        let viewModel = RootViewModel(
            infoText: R.string.localizable.appVersionUnsupportedText(preferredLanguages: selectedLocale.rLanguages),
            buttonTitle: R.string.localizable.commonUpdate(preferredLanguages: selectedLocale.rLanguages)
        )

        view?.didReceive(state: .update(viewModel: viewModel))
    }

    func didFailCheckAppVersion() {
        let viewModel = RootViewModel(
            infoText: R.string.localizable.appVersionJsonLoadingFailed(preferredLanguages: selectedLocale.rLanguages),
            buttonTitle: R.string.localizable.commonRetry(preferredLanguages: selectedLocale.rLanguages)
        )

        view?.didReceive(state: .retry(viewModel: viewModel))
    }
}

extension RootPresenter: Localizable {
    func applyLocalization() {}
}
