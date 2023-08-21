import Foundation
import SoraFoundation

protocol BannersViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: BannersViewModel)
}

protocol BannersInteractorInput: AnyObject {
    func setup(with output: BannersInteractorOutput)
    func markWalletAsBackedUp(_ wallet: MetaAccountModel)
}

final class BannersPresenter {
    // MARK: Private properties

    private weak var view: BannersViewInput?
    private let router: BannersRouterInput
    private let interactor: BannersInteractorInput
    private weak var moduleOutput: BannersModuleOutput?

    private let logger: LoggerProtocol
    private lazy var viewModelFactory: BannersViewModelFactoryProtocol = {
        BannersViewModelFactory()
    }()

    private var wallet: MetaAccountModel?

    // MARK: - Constructors

    init(
        logger: LoggerProtocol,
        moduleOutput: BannersModuleOutput?,
        interactor: BannersInteractorInput,
        router: BannersRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.logger = logger
        self.moduleOutput = moduleOutput
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        guard let wallet = wallet else {
            return
        }
        let viewModel = viewModelFactory.createViewModel(wallet: wallet, locale: selectedLocale)
        DispatchQueue.main.async {
            self.view?.didReceive(viewModel: viewModel)
        }
        moduleOutput?.reloadBannersView()
    }

    private func showNotBackedUpAlert(wallet: MetaAccountModel) {
        let cancelActionTitle = R.string.localizable
            .commonCancel(preferredLanguages: selectedLocale.rLanguages)
        let cancelAction = SheetAlertPresentableAction(title: cancelActionTitle)

        let confirmActionTitle = R.string.localizable
            .backupNotBackedUpConfirm(preferredLanguages: selectedLocale.rLanguages)
        let confirmAction = SheetAlertPresentableAction(
            title: confirmActionTitle,
            style: .pinkBackgroundWhiteText,
            button: UIFactory.default.createMainActionButton()
        ) { [weak self] in
            self?.interactor.markWalletAsBackedUp(wallet)
        }
        let action = [cancelAction, confirmAction]
        let alertTitle = R.string.localizable
            .backupNotBackedUpTitle(preferredLanguages: selectedLocale.rLanguages)
        let alertMessage = R.string.localizable
            .backupNotBackedUpMessage(preferredLanguages: selectedLocale.rLanguages)
        let alertViewModel = SheetAlertPresentableViewModel(
            title: alertTitle,
            message: alertMessage,
            actions: action,
            closeAction: nil,
            actionAxis: .horizontal
        )

        router.present(viewModel: alertViewModel, from: view)
    }
}

// MARK: - BannersViewOutput

extension BannersPresenter: BannersViewOutput {
    func didTapOnCell(at indexPath: IndexPath) {
        guard
            let wallet = wallet,
            let tappedOption = Banners(rawValue: indexPath.row) else {
            return
        }

        switch tappedOption {
        case .backup:
            router.showWalletBackupScreen(for: wallet, from: view)
        case .buyXor:
            break
        }
    }

    func didCloseCell(at indexPath: IndexPath) {
        guard
            let wallet = wallet,
            let tappedOption = Banners(rawValue: indexPath.row) else {
            return
        }

        switch tappedOption {
        case .backup:
            showNotBackedUpAlert(wallet: wallet)
        case .buyXor:
            break
        }
    }

    func didLoad(view: BannersViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - BannersInteractorOutput

extension BannersPresenter: BannersInteractorOutput {
    func didReceive(error: Error) {
        logger.customError(error)
    }

    func didReceive(wallet: MetaAccountModel) {
        self.wallet = wallet
        provideViewModel()
    }
}

// MARK: - Localizable

extension BannersPresenter: Localizable {
    func applyLocalization() {}
}

extension BannersPresenter: BannersModuleInput {
    func reload(with wallet: MetaAccountModel) {
        self.wallet = wallet
        provideViewModel()
    }
}
