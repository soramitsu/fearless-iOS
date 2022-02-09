import Foundation
import SoraFoundation

final class ProfilePresenter {
    weak var view: ProfileViewProtocol?
    var interactor: ProfileInteractorInputProtocol!
    var wireframe: ProfileWireframeProtocol!

    var logger: LoggerProtocol?

    private(set) var viewModelFactory: ProfileViewModelFactoryProtocol

    private(set) var selectedWallet: MetaAccountModel?

    init(viewModelFactory: ProfileViewModelFactoryProtocol) {
        self.viewModelFactory = viewModelFactory
    }
}

extension ProfilePresenter: ProfilePresenterProtocol {
    func setup() {
        updateOptionsViewModel()

        interactor.setup()
    }

    func activateAccountDetails() {
        guard let wallet = selectedWallet else {
            return
        }
        wireframe.showAccountDetails(from: view, metaAccount: wallet)
    }

    func activateOption(at index: UInt) {
        guard let option = ProfileOption(rawValue: index) else {
            return
        }

        switch option {
        case .accountList:
            wireframe.showAccountSelection(from: view)
        case .changePincode:
            wireframe.showPincodeChange(from: view)
        case .language:
            wireframe.showLanguageSelection(from: view)
        case .about:
            wireframe.showAbout(from: view)
        }
    }

    func logout() {
        let removeTitle = R.string.localizable
            .profileLogoutTitle(preferredLanguages: selectedLocale.rLanguages)

        let removeAction = AlertPresentableAction(title: removeTitle, style: .destructive) { [weak self] in
            guard let self = self else { return }
            self.wireframe.showCheckPincode(
                from: self.view,
                output: self
            )
        }

        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: selectedLocale.rLanguages)
        let cancelAction = AlertPresentableAction(title: cancelTitle, style: .cancel)

        let title = R.string.localizable
            .profileLogoutTitle(preferredLanguages: selectedLocale.rLanguages)
        let details = R.string.localizable
            .profileLogoutDescription(preferredLanguages: selectedLocale.rLanguages)
        let viewModel = AlertPresentableViewModel(
            title: title,
            message: details,
            actions: [cancelAction, removeAction],
            closeAction: nil
        )

        wireframe.present(viewModel: viewModel, style: .alert, from: view)
    }
}

extension ProfilePresenter: CheckPincodeModuleOutput {
    func close(view: ControllerBackedProtocol?) {
        wireframe.close(view: view)
    }

    func didCheck() {
        interactor.logout { [weak self] in
            DispatchQueue.main.async {
                self?.wireframe.logout(from: self?.view)
            }
        }
    }
}

extension ProfilePresenter: ProfileInteractorOutputProtocol {
    func didReceive(wallet: MetaAccountModel) {
        selectedWallet = wallet
        updateAccountViewModel()
        updateOptionsViewModel()
    }

    func didReceiveUserDataProvider(error: Error) {
        logger?.debug("Did receive user data provider \(error)")

        if !wireframe.present(error: error, from: view, locale: selectedLocale) {
            _ = wireframe.present(
                error: CommonError.undefined,
                from: view,
                locale: selectedLocale
            )
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

private extension ProfilePresenter {
    func updateAccountViewModel() {
        guard let wallet = selectedWallet else {
            return
        }
        let userDetailsViewModel = viewModelFactory.createUserViewModel(
            from: wallet,
            locale: selectedLocale
        )
        view?.didLoad(userViewModel: userDetailsViewModel)
    }

    func updateOptionsViewModel() {
        guard
            let language = localizationManager?.selectedLanguage
        else {
            return
        }

        let optionViewModels = viewModelFactory.createOptionViewModels(
            language: language,
            locale: selectedLocale
        )
        let logoutViewModel = viewModelFactory.createLogoutViewModel(locale: selectedLocale)
        view?.didLoad(optionViewModels: optionViewModels, logoutViewModel: logoutViewModel)
    }
}
