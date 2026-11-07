import Foundation
import SoraFoundation

final class WalletOptionPresenter {
    // MARK: Private properties

    private weak var view: WalletOptionViewInput?
    private let router: WalletOptionRouterInput
    private let interactor: WalletOptionInteractorInput

    private var wallet: ManagedMetaAccountModel
    private let submissionAuthorizer: SubmissionAuthorizing

    // MARK: - Constructors

    init(
        wallet: ManagedMetaAccountModel,
        interactor: WalletOptionInteractorInput,
        router: WalletOptionRouterInput,
        localizationManager: LocalizationManagerProtocol,
        eventCenter: EventCenterProtocol = EventCenter.shared,
        submissionAuthorizer: SubmissionAuthorizing = SubmissionAuthorizer()
    ) {
        self.wallet = wallet
        self.interactor = interactor
        self.router = router
        self.submissionAuthorizer = submissionAuthorizer
        self.localizationManager = localizationManager
        eventCenter.add(observer: self, dispatchIn: .main)
    }

    // MARK: - Private methods

    private func askAndPerformRemoveWallet() {
        let locale = localizationManager?.selectedLocale

        let removeTitle = R.string.localizable
            .accountDeleteConfirm(preferredLanguages: locale?.rLanguages)

        let removeAction = SheetAlertPresentableAction(
            title: removeTitle,
            style: .pinkBackgroundWhiteText
        ) { [weak self] in
            guard let self else { return }
            // Forgetting a backed-up wallet erases its keys from this device, so it needs the
            // PIN (or trusted biometrics) like any transfer; a cancel removes nothing.
            self.submissionAuthorizer.performAuthorized(from: self.view) { [weak self] in
                self?.interactor.deleteWallet()
            }
        }

        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: locale?.rLanguages)
        let cancelAction = SheetAlertPresentableAction(title: cancelTitle)

        let title = R.string.localizable
            .accountDeleteConfirmationTitle(preferredLanguages: locale?.rLanguages)
        let details = R.string.localizable
            .accountDeleteConfirmationDescription(preferredLanguages: locale?.rLanguages)
        let viewModel = SheetAlertPresentableViewModel(
            title: title,
            message: details,
            actions: [cancelAction, removeAction],
            closeAction: nil,
            icon: R.image.iconWarningBig()
        )

        router.present(viewModel: viewModel, from: view)
    }
}

// MARK: - WalletOptionViewOutput

extension WalletOptionPresenter: WalletOptionViewOutput {
    func changeWalletNameDidTap() {
        router.showChangeWalletName(from: view, for: wallet.info)
    }

    func walletDetailsDidTap() {
        router.showWalletDetails(from: view, for: wallet.info)
    }

    func exportWalletDidTap() {
        router.showExportWallet(from: view, wallet: wallet)
    }

    func deleteWalletDidTap() {
        askAndPerformRemoveWallet()
    }

    func accountScoreDidTap() {
        let address = wallet.info.ethereumAddress?.toHex(includePrefix: true)
        router.presentAccountScore(address: address, from: view)
    }

    func didLoad(view: WalletOptionViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - WalletOptionInteractorOutput

extension WalletOptionPresenter: WalletOptionInteractorOutput {
    func setDeleteButtonIsVisible(_ isVisible: Bool) {
        DispatchQueue.main.async {
            self.view?.setDeleteButtonIsVisible(isVisible)
        }
    }

    func walletRemoved() {
        DispatchQueue.main.async {
            self.router.dismiss(view: self.view)
        }
    }
}

// MARK: - Localizable

extension WalletOptionPresenter: Localizable {
    func applyLocalization() {}
}

extension WalletOptionPresenter: WalletOptionModuleInput {}

extension WalletOptionPresenter: EventVisitorProtocol {
    func processWalletNameChanged(event: WalletNameChanged) {
        guard event.wallet.metaId == wallet.info.metaId else { return }
        updateWallet(wallet.info.replacingName(event.wallet.name))
    }

    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        updateWallet(event.account)
    }

    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        updateWallet(event.account)
    }

    private func updateWallet(_ account: MetaAccountModel) {
        guard account.metaId == wallet.info.metaId else { return }
        wallet = ManagedMetaAccountModel(
            info: account,
            isSelected: wallet.isSelected,
            order: wallet.order,
            balance: wallet.balance
        )
    }
}
