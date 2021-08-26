import Foundation
import SoraFoundation
import FearlessUtils

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
            let language = localizationManager?.selectedLanguage
        else {
            return
        }

        let locale = localizationManager?.selectedLocale ?? Locale.current

        let optionViewModels = viewModelFactory.createOptionViewModels(
            from: userSettings,
            language: language,
            locale: locale
        )
        view?.didLoad(optionViewModels: optionViewModels)
    }

    private func copyAddress() {
        if let address = userSettings?.account.address {
            UIPasteboard.general.string = address

            let locale = localizationManager?.selectedLocale
            let title = R.string.localizable.commonCopied(preferredLanguages: locale?.rLanguages)
            wireframe.presentSuccessNotification(title, from: view)
        }
    }
}

extension ProfilePresenter: ProfilePresenterProtocol {
    func setup() {
        updateOptionsViewModel()

        interactor.setup()
    }

    func activateAccountDetails() {
        let locale = localizationManager?.selectedLocale

        let title = R.string.localizable
            .accountInfoTitle(preferredLanguages: locale?.rLanguages)

        var actions: [AlertPresentableAction] = []

        let accountsTitle = R.string.localizable.profileAccountsTitle(preferredLanguages: locale?.rLanguages)
        let accountAction = AlertPresentableAction(title: accountsTitle) { [weak self] in
            self?.wireframe.showAccountDetails(from: self?.view)
        }

        actions.append(accountAction)

        let copyTitle = R.string.localizable
            .commonCopyAddress(preferredLanguages: locale?.rLanguages)
        let copyAction = AlertPresentableAction(title: copyTitle) { [weak self] in
            self?.copyAddress()
        }

        actions.append(copyAction)

        if
            let address = userSettings?.account.address,
            let url = userSettings?.connection.type.chain.polkascanAddressURL(address) {
            let polkascanTitle = R.string.localizable
                .transactionDetailsViewPolkascan(preferredLanguages: locale?.rLanguages)

            let polkascanAction = AlertPresentableAction(title: polkascanTitle) { [weak self] in
                if let view = self?.view {
                    self?.wireframe.showWeb(url: url, from: view, style: .automatic)
                }
            }

            actions.append(polkascanAction)
        }

        if
            let address = userSettings?.account.address,
            let url = userSettings?.connection.type.chain.subscanAddressURL(address) {
            let subscanTitle = R.string.localizable
                .transactionDetailsViewSubscan(preferredLanguages: locale?.rLanguages)
            let subscanAction = AlertPresentableAction(title: subscanTitle) { [weak self] in
                if let view = self?.view {
                    self?.wireframe.showWeb(url: url, from: view, style: .automatic)
                }
            }

            actions.append(subscanAction)
        }

        let closeTitle = R.string.localizable.commonCancel(preferredLanguages: locale?.rLanguages)

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: nil,
            actions: actions,
            closeAction: closeTitle
        )

        wireframe.present(
            viewModel: viewModel,
            style: .actionSheet,
            from: view
        )
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

        let locale = localizationManager?.selectedLocale ?? Locale.current

        if !wireframe.present(error: error, from: view, locale: locale) {
            _ = wireframe.present(error: CommonError.undefined, from: view, locale: locale)
        }
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
