import Foundation
import SoraFoundation

enum BannersModuleType {
    case independent
    case embed
}

protocol BannersViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: BannersViewModel)
}

protocol BannersInteractorInput: AnyObject {
    func setup(with output: BannersInteractorOutput)
    func markWalletAsBackedUp(_ wallet: MetaAccountModel)
    func subscribeToWallet()
}

final class BannersPresenter {
    // MARK: Private properties

    private weak var view: BannersViewInput?
    private let router: BannersRouterInput
    private let interactor: BannersInteractorInput
    private weak var moduleOutput: BannersModuleOutput?
    private let type: BannersModuleType

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
        localizationManager: LocalizationManagerProtocol,
        type: BannersModuleType,
        wallet: MetaAccountModel?
    ) {
        self.logger = logger
        self.moduleOutput = moduleOutput
        self.interactor = interactor
        self.router = router
        self.type = type
        self.wallet = wallet

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
    func didTapOnBanner(_ banner: Banners) {
        guard let wallet = wallet else {
            return
        }

        switch banner {
        case .backup:
            router.showWalletBackupScreen(for: wallet, from: view)
        case .buyXor:
            break
        case .liquidityPools:
            router.presentLiquidityPools(on: view, wallet: wallet)
        }
    }

    func didCloseBanner(_ banner: Banners) {
        guard let wallet = wallet else {
            return
        }

        switch banner {
        case .backup:
            showNotBackedUpAlert(wallet: wallet)
        case .buyXor:
            break
        case .liquidityPools:
            moduleOutput?.didTapCloseBanners()
        }
    }

    func didLoad(view: BannersViewInput) {
        self.view = view
        interactor.setup(with: self)

        if type == .independent {
            interactor.subscribeToWallet()
        }
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

    func update(banners: [Banners]) {
        let viewModel = viewModelFactory.createViewModel(banners: banners, locale: selectedLocale)
        view?.didReceive(viewModel: viewModel)
    }
}
