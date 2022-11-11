import Foundation
import SoraFoundation

final class NetworkIssuesNotificationPresenter {
    // MARK: Private properties

    private weak var view: NetworkIssuesNotificationViewInput?
    private let router: NetworkIssuesNotificationRouterInput
    private let interactor: NetworkIssuesNotificationInteractorInput

    private var wallet: MetaAccountModel
    private let viewModelFactory: NetworkIssuesNotificationViewModelFactoryProtocol

    private var issues: [ChainIssue]
    private var viewModel: [NetworkIssuesNotificationCellViewModel] = []

    // MARK: - Constructors

    init(
        wallet: MetaAccountModel,
        issues: [ChainIssue],
        viewModelFactory: NetworkIssuesNotificationViewModelFactoryProtocol,
        interactor: NetworkIssuesNotificationInteractorInput,
        router: NetworkIssuesNotificationRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wallet = wallet
        self.issues = issues
        self.viewModelFactory = viewModelFactory
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel(for: issues, locale: selectedLocale)
        self.viewModel = viewModel

        view?.didReceive(viewModel: viewModel)
    }

    private func showMissingAccountOptions(chain: ChainModel) {
        let unused = (wallet.unusedChainIds ?? []).contains(chain.chainId)
        let options: [MissingAccountOption?] = [.create, .import, unused ? nil : .skip]

        router.presentAccountOptions(
            from: view,
            locale: selectedLocale,
            options: options.compactMap { $0 },
            uniqueChainModel: UniqueChainModel(
                meta: wallet,
                chain: chain
            )
        ) { [weak self] chain in
            self?.interactor.markUnused(chain: chain)
        }
    }

    private func showSheetAlert(for chain: ChainModel) {
        let title = [
            chain.name,
            R.string.localizable.commonNetwork(preferredLanguages: selectedLocale.rLanguages)
        ].joined(separator: " ")

        let subtitle = R.string.localizable.networkIssueUnavailable(preferredLanguages: selectedLocale.rLanguages)
        let sheetViewModel = SheetAlertPresentableViewModel(
            title: title,
            message: subtitle,
            actions: [],
            closeAction: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages)
        )
        router.present(viewModel: sheetViewModel, from: view)
    }
}

// MARK: - NetworkIssuesNotificationViewOutput

extension NetworkIssuesNotificationPresenter: NetworkIssuesNotificationViewOutput {
    func dissmis() {
        router.dismiss(view: view)
    }

    func didTapCellAction(indexPath: IndexPath?) {
        guard let indexPath = indexPath else {
            return
        }

        let viewModel = viewModel[indexPath.row]

        switch viewModel.buttonType {
        case .switchNode:
            router.presentNodeSelection(
                from: view,
                chain: viewModel.chain
            )
        case .networkUnavailible:
            showSheetAlert(for: viewModel.chain)
        case .missingAccount:
            showMissingAccountOptions(chain: viewModel.chain)
        }
    }

    func didLoad(view: NetworkIssuesNotificationViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModel()
    }
}

// MARK: - NetworkIssuesNotificationInteractorOutput

extension NetworkIssuesNotificationPresenter: NetworkIssuesNotificationInteractorOutput {
    func didReceiveChainsIssues(issues: [ChainIssue]) {
        self.issues = issues
        provideViewModel()
    }

    func didReceiveWallet(wallet: MetaAccountModel) {
        self.wallet = wallet
    }
}

// MARK: - Localizable

extension NetworkIssuesNotificationPresenter: Localizable {
    func applyLocalization() {
        provideViewModel()
    }
}

extension NetworkIssuesNotificationPresenter: NetworkIssuesNotificationModuleInput {}
