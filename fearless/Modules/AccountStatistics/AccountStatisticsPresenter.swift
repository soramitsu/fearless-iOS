import Foundation
import SoraFoundation

protocol AccountStatisticsViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: AccountStatisticsViewModel?)
}

protocol AccountStatisticsInteractorInput: AnyObject {
    func setup(with output: AccountStatisticsInteractorOutput)
    func fetchAccountStatistics()
}

final class AccountStatisticsPresenter {
    // MARK: Private properties

    private weak var view: AccountStatisticsViewInput?
    private let router: AccountStatisticsRouterInput
    private let interactor: AccountStatisticsInteractorInput
    private let viewModelFactory: AccountStatisticsViewModelFactory

    private var accountStatistics: AccountStatistics?

    // MARK: - Constructors

    init(
        interactor: AccountStatisticsInteractorInput,
        router: AccountStatisticsRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: AccountStatisticsViewModelFactory
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel(accountScore: accountStatistics, locale: selectedLocale)

        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceive(viewModel: viewModel)
        }
    }
}

// MARK: - AccountStatisticsViewOutput

extension AccountStatisticsPresenter: AccountStatisticsViewOutput {
    func didLoad(view: AccountStatisticsViewInput) {
        self.view = view

        DispatchQueue.main.async {
            view.didReceive(viewModel: nil)
        }

        interactor.setup(with: self)
        interactor.fetchAccountStatistics()
    }

    func didTapCloseButton() {
        router.dismiss(view: view)
    }

    func didTapCopyAddress() {
        router.presentStatus(
            with: AddressCopiedEvent(locale: selectedLocale),
            animated: true
        )
    }
}

// MARK: - AccountStatisticsInteractorOutput

extension AccountStatisticsPresenter: AccountStatisticsInteractorOutput {
    func didReceiveAccountStatistics(_ response: AccountStatisticsResponse?) {
        accountStatistics = response?.data
        provideViewModel()
    }

    func didReceiveAccountStatisticsError(_: Error) {}
}

// MARK: - Localizable

extension AccountStatisticsPresenter: Localizable {
    func applyLocalization() {}
}

extension AccountStatisticsPresenter: AccountStatisticsModuleInput {}
