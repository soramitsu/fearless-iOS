import Foundation
import SoraFoundation

final class ProfilePresenter {
	weak var view: ProfileViewProtocol?
	var interactor: ProfileInteractorInputProtocol!
	var wireframe: ProfileWireframeProtocol!

    var logger: LoggerProtocol?

    private(set) var viewModelFactory: ProfileViewModelFactoryProtocol

    private(set) var userData: UserData?
    private(set) var language: Language?

    init(viewModelFactory: ProfileViewModelFactoryProtocol) {
        self.viewModelFactory = viewModelFactory
    }

    private func updateUserDetailsViewModel() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let userDetailsViewModel = viewModelFactory.createUserViewModel(from: userData,
                                                                        locale: locale)
        view?.didLoad(userViewModel: userDetailsViewModel)
    }

    private func updateOptionsViewModel() {
        let language = localizationManager?.selectedLanguage

        let locale = localizationManager?.selectedLocale ?? Locale.current

        let optionViewModels = viewModelFactory.createOptionViewModels(language: language,
                                                                       locale: locale)
        view?.didLoad(optionViewModels: optionViewModels)
    }
}

extension ProfilePresenter: ProfilePresenterProtocol {
    func setup() {
        updateUserDetailsViewModel()
        updateOptionsViewModel()

        interactor.setup()
    }

    func activateUserDetails() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        let copyTitle = R.string.localizable.commonCopyAddress(preferredLanguages: locale.rLanguages)
        let copyAction = AlertPresentableAction(title: copyTitle) { [weak self] in
            UIPasteboard.general.string = self?.userData?.address
        }

        let closeTitle = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        let selectTitle = R.string.localizable.commonSelectOption(preferredLanguages: locale.rLanguages)
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
        case .connection:
            wireframe.showNodeSelection(from: view)
        case .passphrase:
            wireframe.showPassphraseView(from: view)
        case .language:
            wireframe.showLanguageSelection(from: view)
        case .about:
            wireframe.showAbout(from: view)
        }
    }
}

extension ProfilePresenter: ProfileInteractorOutputProtocol {
    func didReceive(userData: UserData) {
        self.userData = userData
        updateUserDetailsViewModel()
    }

    func didReceiveUserDataProvider(error: Error) {
        logger?.debug("Did receive user data provider \(error)")
    }
}

extension ProfilePresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateUserDetailsViewModel()
            updateOptionsViewModel()
        }
    }
}
