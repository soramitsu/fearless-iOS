import Foundation
import SoraFoundation

final class ProfilePresenter {
	weak var view: ProfileViewProtocol?
	var interactor: ProfileInteractorInputProtocol!
	var wireframe: ProfileWireframeProtocol!

    var logger: LoggerProtocol?

    private(set) var viewModelFactory: ProfileViewModelFactoryProtocol

    private(set) var userSettings: UserSettings?

    init(viewModelFactory: ProfileViewModelFactoryProtocol) {
        self.viewModelFactory = viewModelFactory
    }

    private func updateAccountViewModel() {
        guard let userSettings = userSettings else {
            return
        }

        let locale = localizationManager?.selectedLocale ?? Locale.current
        let userDetailsViewModel = viewModelFactory.createUserViewModel(from: userSettings, locale: locale)
        view?.didLoad(userViewModel: userDetailsViewModel)
    }

    private func updateOptionsViewModel() {
        guard
            let userSettings = userSettings,
            let language = localizationManager?.selectedLanguage else {
            return
        }

        let locale = localizationManager?.selectedLocale ?? Locale.current

        let optionViewModels = viewModelFactory.createOptionViewModels(from: userSettings,
                                                                       language: language,
                                                                       locale: locale)
        view?.didLoad(optionViewModels: optionViewModels)
    }
}

extension ProfilePresenter: ProfilePresenterProtocol {
    func setup() {
        updateOptionsViewModel()

        interactor.setup()
    }

    func activateAccountDetails() {
        wireframe.showAccountDetails(from: view)
    }

    func activeteAccountCopy() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        let selectTitle = R.string.localizable.commonSelectOption(preferredLanguages: locale.rLanguages)
        let closeTitle = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)

        let copyTitle = R.string.localizable.commonCopyAddress(preferredLanguages: locale.rLanguages)

        let copyAction = AlertPresentableAction(title: copyTitle) { [weak self] in
            UIPasteboard.general.string = self?.userSettings?.account.address
        }

        let viewModel = AlertPresentableViewModel(title: selectTitle,
                                                  message: nil,
                                                  actions: [copyAction],
                                                  closeAction: closeTitle)

        wireframe.present(viewModel: viewModel,
                          style: .actionSheet,
                          from: view)
    }

    func activateOption(at index: UInt) {
        guard let option = ProfileOption(rawValue: index) else {
            return
        }

        switch option {
        case .accountList:
            wireframe.showAccountSelection(from: view)
        case .connectionList:
            wireframe.showConnectionSelection(from: view)
        case .changePincode:
            wireframe.showPincodeChange(from: view)
        case .language:
            wireframe.showLanguageSelection(from: view)
        case .about:
            wireframe.showAbout(from: view)
        }
    }
}

extension ProfilePresenter: ProfileInteractorOutputProtocol {
    func didReceive(userSettings: UserSettings) {
        self.userSettings = userSettings
        updateAccountViewModel()
        updateOptionsViewModel()
    }

    func didReceiveUserDataProvider(error: Error) {
        logger?.debug("Did receive user data provider \(error)")
    }
}

extension ProfilePresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateAccountViewModel()
            updateOptionsViewModel()
        }
    }
}
