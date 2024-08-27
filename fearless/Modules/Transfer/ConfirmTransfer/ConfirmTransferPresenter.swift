import Foundation
import Web3
import SoraFoundation
import SSFModels

@MainActor
protocol ConfirmTransferViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: WalletSendConfirmViewModel)
    func didReceiveContinueButton(isReady: Bool)
    func didStopLoading()
}

protocol ConfirmTransferInteractorInput: AnyObject {
    func setup(with output: TransferInteractorOutput)
}

final class ConfirmTransferPresenter {
    // MARK: Private properties

    private weak var view: ConfirmTransferViewInput?
    private let router: ConfirmTransferRouterInput
    private let interactor: TransferInteractorInput
    private let viewModelFactory: WalletSendConfirmViewModelFactoryProtocol
    private let logger: LoggerProtocol
    private let useCase: TransferFlowUseCase
    private let scamInfo: ScamInfo?

    // MARK: - Constructors

    init(
        interactor: TransferInteractorInput,
        router: ConfirmTransferRouterInput,
        viewModelFactory: WalletSendConfirmViewModelFactoryProtocol,
        useCase: TransferFlowUseCase,
        sendFlow: SendFlowInitialData,
        scamInfo: ScamInfo?,
        logger: LoggerProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.useCase = useCase
        self.scamInfo = scamInfo
        self.logger = logger
        self.localizationManager = localizationManager
        setupBindings()

        Task {
            do {
                try await useCase.handle(initialData: sendFlow)
                await provideIsReady()
                await provideViewModel()
            } catch {
                logger.customError(error)
            }
        }
    }

    // MARK: - Private methods

    private func provideViewModel() async {
        do {
            let viewModel = try viewModelFactory.buildViewModel(
                useCase: useCase,
                scamInfo: scamInfo,
                locale: selectedLocale
            )

            await view?.didReceive(viewModel: viewModel)
        } catch {
            logger.customError(error)
        }
    }

    private func provideIsReady() async {
        let isReady = useCase.isReadyToContinue()
        await view?.didReceiveContinueButton(isReady: isReady)
    }

    private func setupBindings() {
        useCase.provideFeeViewModel = { [weak self] in
            Task { [weak self] in
                await self?.provideViewModel()
                await self?.provideIsReady()
            }
        }
    }

    private func submit() {
        Task {
            do {
                guard
                    let transfer = useCase.transfer,
                    let chainAsset = useCase.selectedChainAsset
                else {
                    throw ConvenienceError(error: "Missing requared params")
                }
                let hash = try await interactor.submit(transfer: transfer, chainAsset: chainAsset)

                await view?.didStopLoading()
                Task { @MainActor in
                    router.complete(on: view, title: hash, chainAsset: chainAsset)
                }
            } catch {
                guard let view else { return }
                await view.didStopLoading()
                Task { @MainActor in
                    if let rpcError = error as? RPCResponse<EthereumData>.Error, rpcError.code == -32000 {
                        router.presentAmountTooHigh(from: view, locale: selectedLocale)
                        return
                    }

                    if !router.present(error: error, from: view, locale: selectedLocale) {
                        router.presentExtrinsicFailed(from: view, locale: selectedLocale)
                    }
                    logger.customError(error)
                }
            }
        }
    }
}

// MARK: - ConfirmTransferViewOutput

extension ConfirmTransferPresenter: ConfirmTransferViewOutput {
    func didTapConfirmButton() {
        do {
            let validators = try useCase.getValidators(validationCase: .all, locale: selectedLocale)
            DataValidationRunner(validators: validators).runValidation { [weak self] in
                guard let self else { return }
                self.submit()
            }
        } catch {
            logger.customError(error)
        }
    }

    @MainActor
    func didTapBackButton() {
        router.close(view: view)
    }

    @MainActor
    func didTapScamWarningButton() {
        guard let chainAsset = useCase.selectedChainAsset else {
            return
        }
        let title = R.string.localizable.scamWarningAlertTitle(
            chainAsset.asset.symbol.uppercased(),
            preferredLanguages: selectedLocale.rLanguages
        )
        let message = R.string.localizable.scamWarningAlertSubtitle(
            chainAsset.asset.symbolUppercased,
            preferredLanguages: selectedLocale.rLanguages
        )

        let sheetViewModel = SheetAlertPresentableViewModel(
            title: title,
            message: message,
            actions: [],
            closeAction: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages),
            icon: R.image.iconWarningBig()
        )
        router.present(
            viewModel: sheetViewModel,
            from: view
        )
    }

    func didLoad(view: ConfirmTransferViewInput) {
        self.view = view
        Task { await interactor.setup(with: self) }
    }
}

// MARK: - ConfirmTransferInteractorOutput

extension ConfirmTransferPresenter: TransferInteractorOutput {}

// MARK: - Localizable

extension ConfirmTransferPresenter: Localizable {
    func applyLocalization() {}
}

extension ConfirmTransferPresenter: ConfirmTransferModuleInput {}
