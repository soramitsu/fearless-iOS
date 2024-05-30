import Foundation
import SoraFoundation
import SSFModels

final class NetworkIssuesNotificationPresenter {
    // MARK: Private properties

    private weak var view: NetworkIssuesNotificationViewInput?
    private let router: NetworkIssuesNotificationRouterInput
    private let interactor: NetworkIssuesNotificationInteractorInput

    private var wallet: MetaAccountModel
    private let viewModelFactory: NetworkIssuesNotificationViewModelFactoryProtocol

    private var issues: [ChainIssue]
    private var chainSettings: [ChainSettings]?
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
        guard let chainSettings = chainSettings else {
            return
        }

        let viewModel = viewModelFactory.buildViewModel(for: issues, locale: selectedLocale, chainSettings: chainSettings)
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
        let muteAction = SheetAlertPresentableAction(title: R.string.localizable.networkIssuesHideActionTitle(preferredLanguages: selectedLocale.rLanguages), style: .pinkBackgroundWhiteText) { [weak self] in
            self?.interactor.mute(chain: chain)
        }
        let sheetViewModel = SheetAlertPresentableViewModel(
            title: title,
            message: subtitle,
            actions: [muteAction],
            closeAction: nil,
            icon: R.image.iconWarningBig()
        )
        router.present(viewModel: sheetViewModel, from: view)
    }

    private func showNodeSelectionAlert(viewModel: NetworkIssuesNotificationCellViewModel) {
        let title = [
            R.string.localizable.commonResolve(preferredLanguages: selectedLocale.rLanguages),
            "\n",
            viewModel.chain.name,
            R.string.localizable.networkIssueStub(preferredLanguages: selectedLocale.rLanguages)
        ].joined(separator: " ")
        let changeNodeAction = SheetAlertPresentableAction(title: R.string.localizable.switchNode(preferredLanguages: selectedLocale.rLanguages), style: .grayBackgroundWhiteText) {
            self.router.presentNodeSelection(
                from: self.view,
                chain: viewModel.chain
            )
        }
        let muteAction = SheetAlertPresentableAction(title: R.string.localizable.networkIssuesHideActionTitle(preferredLanguages: selectedLocale.rLanguages), style: .pinkBackgroundWhiteText) { [weak self] in
            self?.interactor.mute(chain: viewModel.chain)
        }
        let sheetViewModel = SheetAlertPresentableViewModel(
            title: title,
            message: nil,
            actions: [changeNodeAction, muteAction],
            closeAction: nil,
            icon: nil
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
            showNodeSelectionAlert(viewModel: viewModel)
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
        self.issues = issues.compactMap { issue in
            guard self.issues.isNotEmpty else {
                return issue
            }
            switch issue {
            case let .network(chains):
                let filtered = chains.filter { chain in
                    self.issues.contains(where: { issue in
                        if case let .network(chains) = issue {
                            return chains.contains(where: { $0.chainId == chain.chainId })
                        } else {
                            return false
                        }
                    })
                }
                return .network(chains: filtered)

            case let .missingAccount(chains):
                let filtered = chains.filter { chain in
                    self.issues.contains(where: { issue in
                        if case let .missingAccount(chains) = issue {
                            return chains.contains(where: { $0.chainId == chain.chainId })
                        } else {
                            return false
                        }
                    })
                }
                return .missingAccount(chains: filtered)
            }
        }
        provideViewModel()
    }

    func didReceiveWallet(wallet: MetaAccountModel) {
        self.wallet = wallet
    }

    func didReceive(chainSettings: [ChainSettings]) {
        self.chainSettings = chainSettings
        provideViewModel()
    }
}

// MARK: - Localizable

extension NetworkIssuesNotificationPresenter: Localizable {
    func applyLocalization() {
        provideViewModel()
    }
}

extension NetworkIssuesNotificationPresenter: NetworkIssuesNotificationModuleInput {}
