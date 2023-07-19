import Foundation
import SoraFoundation

protocol BannersViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: BannersViewModel)
}

protocol BannersInteractorInput: AnyObject {
    func setup(with output: BannersInteractorOutput)
}

final class BannersPresenter {
    // MARK: Private properties

    private weak var view: BannersViewInput?
    private let router: BannersRouterInput
    private let interactor: BannersInteractorInput
    private weak var moduleOutput: BannersModuleOutput?

    private lazy var viewModelFactory: BannersViewModelFactoryProtocol = {
        BannersViewModelFactory()
    }()

    private var wallet: MetaAccountModel?

    // MARK: - Constructors

    init(
        moduleOutput: BannersModuleOutput?,
        interactor: BannersInteractorInput,
        router: BannersRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
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

    func didLoad(view: BannersViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - BannersInteractorOutput

extension BannersPresenter: BannersInteractorOutput {
    func didReceive(error: Error) {
        print(error)
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
