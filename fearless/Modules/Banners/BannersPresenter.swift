import Foundation
import SSFModels
import SoraFoundation

enum BannersModuleType {
    case independent
    case embed
}

protocol BannersViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: BannersViewModel)
}

protocol BannersInteractorInput: AnyObject {
    var shouldShowAddWalletBanner: Bool { get set }
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

    private var wallets: [MetaAccountModel] = []

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
        if let wallet {
            wallets.append(wallet)
        }

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory.createViewModel(
            wallets: wallets,
            locale: selectedLocale,
            shouldShowAddWalletBanner: interactor.shouldShowAddWalletBanner
        )
        DispatchQueue.main.async {
            self.view?.didReceive(viewModel: viewModel)
        }

        moduleOutput?.reloadBannersView(bannersCount: viewModel.banners.count)
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
        guard let wallet = SelectedWalletSettings.shared.value else {
            return
        }

        switch banner {
        case .backup:
            router.showWalletBackupScreen(for: wallet, from: view)
        case .buyXor:
            break
        case .liquidityPools:
            router.presentLiquidityPools(on: view, wallet: wallet, chainId: Chain.soraMain.genesisHash)
        case .liquidityPoolsTest:
            router.presentLiquidityPools(on: view, wallet: wallet, chainId: Chain.soraTest.genesisHash)
        case .addRegularWallet:
            router.showCreateNewWallet(ecosystem: .regular, from: view)
        case .addTonWallet:
            router.showCreateNewWallet(ecosystem: .ton, from: view)
        }
    }

    func didCloseBanner(_ banner: Banners) {
        switch banner {
        case .backup:
            guard let wallet = SelectedWalletSettings.shared.value else {
                return
            }
            showNotBackedUpAlert(wallet: wallet)
        case .buyXor:
            break
        case .liquidityPools, .liquidityPoolsTest:
            moduleOutput?.didTapCloseBanners()
        case .addRegularWallet:
            interactor.shouldShowAddWalletBanner = false
            provideViewModel()
        case .addTonWallet:
            interactor.shouldShowAddWalletBanner = false
            provideViewModel()
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
        wallets = wallets.filter { $0.metaId != wallet.metaId }
        wallets.append(wallet)
        provideViewModel()
    }
}

// MARK: - Localizable

extension BannersPresenter: Localizable {
    func applyLocalization() {}
}

extension BannersPresenter: BannersModuleInput {
    func reload(with wallet: MetaAccountModel) {
        wallets = wallets.filter { $0.metaId != wallet.metaId }
        wallets.append(wallet)
        provideViewModel()
    }

    func update(banners: [Banners]) {
        let viewModel = viewModelFactory.createViewModel(banners: banners, locale: selectedLocale)

        view?.didReceive(viewModel: viewModel)
    }

    func reload() {
        provideViewModel()
    }
}
