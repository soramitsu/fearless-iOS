import Foundation
import SoraFoundation

protocol BackupWalletNameViewInput: ControllerBackedProtocol, HiddableBarWhenPushed, LoadableViewProtocol {
    func setInputViewModel(_ viewModel: InputViewModelProtocol)
}

protocol BackupWalletNameInteractorInput: AnyObject {
    func setup(with output: BackupWalletNameInteractorOutput)
    func save(wallet: MetaAccountModel)
}

enum WalletNameScreenMode {
    case editing(MetaAccountModel)
    case create

    init(wallet: MetaAccountModel?) {
        guard let wallet = wallet else {
            self = .create
            return
        }
        self = .editing(wallet)
    }
}

final class BackupWalletNamePresenter {
    // MARK: Private properties

    private weak var view: BackupWalletNameViewInput?
    private let router: BackupWalletNameRouterInput
    private let interactor: BackupWalletNameInteractorInput

    private var mode: WalletNameScreenMode

    private let nameInputViewModel = {
        InputViewModel(inputHandler: InputHandler(predicate: NSPredicate.notEmpty))
    }()

    // MARK: - Constructors

    init(
        mode: WalletNameScreenMode,
        interactor: BackupWalletNameInteractorInput,
        router: BackupWalletNameRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.mode = mode
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - BackupWalletNameViewOutput

extension BackupWalletNamePresenter: BackupWalletNameViewOutput {
    func didBackButtonTapped() {
        router.dismiss(view: view)
    }

    func didContinueButtonTapped() {
        let walletName = nameInputViewModel.inputHandler.normalizedValue
        switch mode {
        case let .editing(wallet):
            view?.didStartLoading()
            let replacingNameWallet = wallet.replacingName(walletName)
            interactor.save(wallet: replacingNameWallet)
        case .create:
            router.showWarningsScreen(walletName: walletName, from: view)
        }
    }

    func didLoad(view: BackupWalletNameViewInput) {
        self.view = view
        interactor.setup(with: self)
        switch mode {
        case let .editing(wallet):
            nameInputViewModel.inputHandler.changeValue(to: wallet.name)
        case .create:
            break
        }
        view.setInputViewModel(nameInputViewModel)
    }
}

// MARK: - BackupWalletNameInteractorOutput

extension BackupWalletNamePresenter: BackupWalletNameInteractorOutput {
    func didReceiveSaveOperation(result: Result<MetaAccountModel, Error>) {
        view?.didStopLoading()
        switch result {
        case .success:
            router.complete(view: view)
        case let .failure(failure):
            router.present(error: failure, from: view, locale: selectedLocale)
        }
    }
}

// MARK: - Localizable

extension BackupWalletNamePresenter: Localizable {
    func applyLocalization() {}
}

extension BackupWalletNamePresenter: BackupWalletNameModuleInput {}
