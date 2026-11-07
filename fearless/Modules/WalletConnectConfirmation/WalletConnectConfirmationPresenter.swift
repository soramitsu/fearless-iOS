import Foundation
import SoraFoundation

protocol WalletConnectConfirmationViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(viewModel: WalletConnectConfirmationViewModel)
}

protocol WalletConnectConfirmationInteractorInput: AnyObject {
    func setup(with output: WalletConnectConfirmationInteractorOutput)
    func reject() async throws
    func approve() async throws -> String?
}

final class WalletConnectConfirmationPresenter {
    // MARK: Private properties

    private weak var view: WalletConnectConfirmationViewInput?
    private let router: WalletConnectConfirmationRouterInput
    private let interactor: WalletConnectConfirmationInteractorInput

    private let inputData: WalletConnectConfirmationInputData
    private let viewModelFactory: WalletConnectConfirmationViewModelFactory
    /// From the confirm tap until the signing finishes: the PIN screen may be up. A request that ends meanwhile is
    /// caught by the interactor's own checks, so the flow is not closed under the PIN screen.
    private(set) var isSigning = false

    // MARK: - Constructors

    init(
        inputData: WalletConnectConfirmationInputData,
        viewModelFactory: WalletConnectConfirmationViewModelFactory,
        interactor: WalletConnectConfirmationInteractorInput,
        router: WalletConnectConfirmationRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.inputData = inputData
        self.viewModelFactory = viewModelFactory
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel(locale: selectedLocale)
        view?.didReceive(viewModel: viewModel)
    }

    private func showAllDone(hash: String?) {
        router.showAllDone(
            chain: inputData.signingRequest.chain,
            hashString: hash,
            view: view
        ) { [weak self, weak view] in
            self?.router.dismiss(view: self?.view)
            view?.controller.onInteractionDismiss()
        }
    }

    /// Signing for the request's network was paused while it was open. The request was declined; closing the
    /// notice ends the flow.
    private func showSigningPaused() {
        guard let view = view else {
            return
        }
        let languages = selectedLocale.rLanguages
        let close = SheetAlertPresentableAction(
            title: R.string.localizable.commonClose(preferredLanguages: languages),
            handlerAfterDismissal: true
        ) { [weak self] in
            self?.router.dismiss(view: self?.view)
            self?.view?.controller.onInteractionDismiss()
        }
        router.present(
            viewModel: SheetAlertPresentableViewModel(
                title: R.string.localizable.walletConnectSigningPausedTitle(preferredLanguages: languages),
                message: R.string.localizable.walletConnectSigningPausedMessage(preferredLanguages: languages),
                actions: [close],
                closeAction: nil,
                icon: R.image.iconWarningBig()
            ),
            from: view
        )
    }

    /// The dApp stopped waiting for the request while it was open. Nothing was sent to it; closing the notice ends
    /// the flow.
    func showRequestEnded() {
        guard let view = view else {
            return
        }
        let languages = selectedLocale.rLanguages
        let close = SheetAlertPresentableAction(
            title: R.string.localizable.commonClose(preferredLanguages: languages),
            handlerAfterDismissal: true
        ) { [weak self] in
            self?.router.dismiss(view: self?.view)
            self?.view?.controller.onInteractionDismiss()
        }
        router.present(
            viewModel: SheetAlertPresentableViewModel(
                title: R.string.localizable.walletConnectRequestEndedTitle(preferredLanguages: languages),
                message: R.string.localizable.walletConnectRequestEndedMessage(preferredLanguages: languages),
                actions: [close],
                closeAction: nil,
                icon: R.image.iconWarningBig()
            ),
            from: view
        )
    }

    private func show(error: Error) {
        guard let view = view else {
            return
        }
        router.presentError(
            for: "",
            message: "\(error)",
            view: view,
            locale: selectedLocale
        )
    }
}

// MARK: - WalletConnectConfirmationViewOutput

extension WalletConnectConfirmationPresenter: WalletConnectConfirmationViewOutput {
    func backButtonDidTapped() {
        router.dismiss(view: view)
    }

    func rawDataDidTapped() {
        router.showRawData(json: inputData.signingRequest.rawDetails, from: view)
    }

    func confirmDidTapped() {
        guard !isSigning else {
            return
        }

        isSigning = true
        view?.didStartLoading()
        Task {
            do {
                let hash = try await interactor.approve()
                await MainActor.run {
                    isSigning = false
                    showAllDone(hash: hash)
                    view?.didStopLoading()
                }
            } catch WalletConnectSigningError.paused {
                // The app hears that the request was declined; nothing was signed.
                try? await interactor.reject()
                await MainActor.run {
                    isSigning = false
                    view?.didStopLoading()
                    showSigningPaused()
                }
            } catch WalletConnectSigningError.requestEnded {
                await MainActor.run {
                    isSigning = false
                    view?.didStopLoading()
                    showRequestEnded()
                }
            } catch WalletConnectSigningError.notAuthorized {
                // The user closed the PIN screen; the request stays open to retry or reject.
                await MainActor.run {
                    isSigning = false
                    view?.didStopLoading()
                }
            } catch {
                await MainActor.run {
                    isSigning = false
                    view?.didStopLoading()
                    show(error: error)
                }
            }
        }
    }

    func didLoad(view: WalletConnectConfirmationViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModel()
    }
}

// MARK: - WalletConnectConfirmationInteractorOutput

extension WalletConnectConfirmationPresenter: WalletConnectConfirmationInteractorOutput {}

// MARK: - Localizable

extension WalletConnectConfirmationPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            provideViewModel()
        }
    }
}

extension WalletConnectConfirmationPresenter: WalletConnectConfirmationModuleInput {}
