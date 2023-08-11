import Foundation
import SoraFoundation

protocol WalletNameViewInput: ControllerBackedProtocol, HiddableBarWhenPushed, LoadableViewProtocol {
    func setInputViewModel(_ viewModel: InputViewModelProtocol)
}

protocol WalletNameInteractorInput: AnyObject {
    func setup(with output: WalletNameInteractorOutput)
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

final class WalletNamePresenter {
    // MARK: Private properties

    private weak var view: WalletNameViewInput?
    private let router: WalletNameRouterInput
    private let interactor: WalletNameInteractorInput

    private var mode: WalletNameScreenMode

    private let nameInputViewModel = {
        InputViewModel(inputHandler: InputHandler(predicate: NSPredicate.notEmpty))
    }()

    // MARK: - Constructors

    init(
        mode: WalletNameScreenMode,
        interactor: WalletNameInteractorInput,
        router: WalletNameRouterInput,
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

extension WalletNamePresenter: WalletNameViewOutput {
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

    func didLoad(view: WalletNameViewInput) {
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

extension WalletNamePresenter: WalletNameInteractorOutput {
    func didReceiveSaveOperation(result: Result<MetaAccountModel, Error>) {
        view?.didStopLoading()
        switch result {
        case .success:
            router.complete()
        case let .failure(failure):
            router.present(error: failure, from: view, locale: selectedLocale)
        }
    }
}

// MARK: - Localizable

extension WalletNamePresenter: Localizable {
    func applyLocalization() {}
}

extension WalletNamePresenter: WalletNameModuleInput {}
