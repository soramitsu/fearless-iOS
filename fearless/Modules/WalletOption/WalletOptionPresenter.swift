import Foundation
import SoraFoundation

final class WalletOptionPresenter {
    // MARK: Private properties

    private weak var view: WalletOptionViewInput?
    private let router: WalletOptionRouterInput
    private let interactor: WalletOptionInteractorInput

    private let wallet: ManagedMetaAccountModel

    // MARK: - Constructors

    init(
        wallet: ManagedMetaAccountModel,
        interactor: WalletOptionInteractorInput,
        router: WalletOptionRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wallet = wallet
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
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
            self?.interactor.deleteWallet()
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
