import Foundation
import SoraFoundation

protocol CrossChainConfirmationViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(viewModel: CrossChainConfirmationViewModel)
}

protocol CrossChainConfirmationInteractorInput: AnyObject {
    func setup(with output: CrossChainConfirmationInteractorOutput)
    /// `confirmingRepeat` is set only after the user explicitly chose to send a transfer that matches an unresolved one.
    func submit(confirmingRepeat: Bool)
}

final class CrossChainConfirmationPresenter {
    // MARK: Private properties

    private weak var view: CrossChainConfirmationViewInput?
    private let router: CrossChainConfirmationRouterInput
    private let interactor: CrossChainConfirmationInteractorInput

    private let teleportData: CrossChainConfirmationData
    private let viewModelFactory: CrossChainConfirmationViewModelFactoryProtocol

    // MARK: - Constructors

    init(
        teleportData: CrossChainConfirmationData,
        viewModelFactory: CrossChainConfirmationViewModelFactoryProtocol,
        interactor: CrossChainConfirmationInteractorInput,
        router: CrossChainConfirmationRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.teleportData = teleportData
        self.viewModelFactory = viewModelFactory
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory.createViewModel(with: teleportData)
        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - CrossChainConfirmationViewOutput

extension CrossChainConfirmationPresenter: CrossChainConfirmationViewOutput {
    func didLoad(view: CrossChainConfirmationViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModel()
    }

    func backButtonDidTapped() {
        router.dismiss(view: view)
    }

    func confirmButtonTapped() {
        do {
            try ReviewedCrossChainSubmissionValidator.validate(
                origin: teleportData.originChainAsset,
                destination: teleportData.destChainModel,
                reviewedRoute: teleportData.reviewedRoute,
                mutationsEnabled: MultiChainFeaturePolicy.current.crossChainMutationsEnabled
            )
        } catch {
            guard let view else { return }
            if !router.present(error: error, from: view, locale: selectedLocale) {
                router.present(
                    message: error.localizedDescription,
                    title: "Route unavailable",
                    closeAction: nil,
                    from: view,
                    actions: []
                )
            }
            return
        }
        view?.didStartLoading()
        interactor.submit(confirmingRepeat: false)
    }
}

// MARK: - CrossChainConfirmationInteractorOutput

extension CrossChainConfirmationPresenter: CrossChainConfirmationInteractorOutput {
    func didTransfer(result: Result<ReviewedCrossChainSubmissionResult, Error>) {
        view?.didStopLoading()

        switch result {
        case let .success(.awaitingBridge(extrinsicHash)):
            router.complete(
                on: view,
                hash: extrinsicHash,
                title: localized(
                    "cross_chain.submitted.awaiting_bridge.title",
                    "Submitted, awaiting bridge"
                ),
                description: String(
                    format: localized(
                        "cross_chain.submitted.awaiting_bridge.message",
                        "%@ accepted the transfer. %@ credits the recipient after the bridge relays it, usually within 2–10 minutes. Do not send it again; Fearless asks before sending the same transfer twice."
                    ),
                    teleportData.originChainAsset.chain.name,
                    teleportData.destChainModel.name
                ),
                chainAsset: teleportData.originChainAsset
            )
        case let .success(.unconfirmed(extrinsicHash)):
            router.complete(
                on: view,
                hash: extrinsicHash,
                title: localized(
                    "cross_chain.submitted.unconfirmed.title",
                    "Submitted, not yet confirmed"
                ),
                description: String(
                    format: localized(
                        "cross_chain.submitted.unconfirmed.message",
                        "The %@ network accepted the transfer, but Fearless did not see it included yet. Look the hash up in a block explorer before sending it again."
                    ),
                    teleportData.originChainAsset.chain.name
                ),
                chainAsset: teleportData.originChainAsset
            )
        case let .failure(error):
            guard let view = view else {
                return
            }

            // These carry the exact reason, such as a changed destination fee or the wrong network; the generic
            // presenter knows neither type and would only say that the transaction failed.
            if error is ReviewedCrossChainDispatchError || error is ReviewedCrossChainSubmissionError {
                router.present(
                    message: error.localizedDescription,
                    title: localized("cross_chain.transfer_not_completed", "Transfer not completed"),
                    closeAction: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages),
                    from: view,
                    actions: []
                )
                return
            }

            if !router.present(error: error, from: view, locale: selectedLocale) {
                router.presentExtrinsicFailed(from: view, locale: selectedLocale)
            }
        }
    }

    func didFindUnresolvedSubmission(_ record: ReviewedCrossChainSubmissionRecord) {
        view?.didStopLoading()

        var sendAgain = false
        let sendAgainAction = SheetAlertPresentableAction(
            title: localized("cross_chain.unresolved.send_again", "Send it again"),
            style: .pinkBackgroundWhiteText,
            handler: { sendAgain = true }
        )
        let formatter = DateFormatter()
        formatter.locale = selectedLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let message = String(
            format: localized(
                "cross_chain.unresolved.message",
                "The same transfer was sent on %@ and has not been confirmed as failed. It may still arrive, and a second transfer cannot be undone.\n%@\n%@"
            ),
            formatter.string(from: record.createdAt),
            record.summary,
            record.extrinsicHash ?? localized("cross_chain.unresolved.no_hash", "No transaction hash was returned.")
        )
        let viewModel = SheetAlertPresentableViewModel(
            title: localized("cross_chain.unresolved.title", "This transfer may already be on its way"),
            message: message,
            actions: [sendAgainAction],
            closeAction: R.string.localizable.commonCancel(preferredLanguages: selectedLocale.rLanguages),
            dismissCompletion: { [weak self] in
                guard sendAgain, let self else {
                    return
                }
                self.view?.didStartLoading()
                self.interactor.submit(confirmingRepeat: true)
            },
            icon: R.image.iconWarningBig()
        )
        router.present(viewModel: viewModel, from: view)
    }

    private func localized(_ key: String, _ fallback: String) -> String {
        NSLocalizedString(key, value: fallback, comment: "")
    }
}

// MARK: - Localizable

extension CrossChainConfirmationPresenter: Localizable {
    func applyLocalization() {}
}

extension CrossChainConfirmationPresenter: CrossChainConfirmationModuleInput {}
