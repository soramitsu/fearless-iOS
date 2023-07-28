import Foundation
import SoraFoundation

protocol BackupCreatePasswordViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func setPasswordInputViewModel(_ viewModel: InputViewModelProtocol)
    func setPasswordConfirmationViewModel(_ viewModel: InputViewModelProtocol)
    func setPassword(isMatched: Bool)
}

protocol BackupCreatePasswordInteractorInput: AnyObject {
    func setup(with output: BackupCreatePasswordInteractorOutput)
    func createAndBackupAccount(password: String)
    func hasPincode() -> Bool
}

final class BackupCreatePasswordPresenter {
    // MARK: Private properties

    private weak var view: BackupCreatePasswordViewInput?
    private let router: BackupCreatePasswordRouterInput
    private let interactor: BackupCreatePasswordInteractorInput

    private let flow: BackupCreatePasswordFlow
    private weak var moduleOutput: BackupCreatePasswordModuleOutput?

    private let passwordInputViewModel = {
        InputViewModel(inputHandler: InputHandler(predicate: NSPredicate.notEmpty))
    }()

    private let confirmationViewModel = {
        InputViewModel(inputHandler: InputHandler(predicate: NSPredicate.notEmpty))
    }()

    // MARK: - Constructors

    init(
        flow: BackupCreatePasswordFlow,
        moduleOutput: BackupCreatePasswordModuleOutput?,
        interactor: BackupCreatePasswordInteractorInput,
        router: BackupCreatePasswordRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.flow = flow
        self.moduleOutput = moduleOutput
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func proceed() {
        let password = passwordInputViewModel.inputHandler.normalizedValue

        guard password == confirmationViewModel.inputHandler.normalizedValue else {
            view?.setPassword(isMatched: false)
            return
        }

        interactor.createAndBackupAccount(password: password)
    }
}

// MARK: - BackupCreatePasswordViewOutput

extension BackupCreatePasswordPresenter: BackupCreatePasswordViewOutput {
    func didTapBackButton() {
        router.pop(from: view)
    }

    func didTapContinueButton() {
        view?.didStartLoading()
        proceed()
    }

    func didLoad(view: BackupCreatePasswordViewInput) {
        self.view = view
        interactor.setup(with: self)
        view.setPasswordInputViewModel(passwordInputViewModel)
        view.setPasswordConfirmationViewModel(confirmationViewModel)
    }
}

// MARK: - BackupCreatePasswordInteractorOutput

extension BackupCreatePasswordPresenter: BackupCreatePasswordInteractorOutput {
    func didReceive(error: Error) {
        router.present(error: error, from: view, locale: selectedLocale)
    }

    func didComplete() {
        view?.didStopLoading()
        switch flow {
        case .createWallet:
            if interactor.hasPincode() {
                router.dismiss(from: view)
            } else {
                router.showPinSetup()
            }
        case .backupWallet:
            moduleOutput?.backupDidComplete()
            router.pop(from: view)
        }
    }
}

// MARK: - Localizable

extension BackupCreatePasswordPresenter: Localizable {
    func applyLocalization() {}
}

extension BackupCreatePasswordPresenter: BackupCreatePasswordModuleInput {}
