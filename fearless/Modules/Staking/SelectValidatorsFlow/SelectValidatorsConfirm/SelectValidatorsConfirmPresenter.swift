import Foundation
import CommonWallet
import Web3
import SSFModels

final class SelectValidatorsConfirmPresenter {
    weak var view: SelectValidatorsConfirmViewProtocol?
    let wireframe: SelectValidatorsConfirmWireframeProtocol
    let interactor: SelectValidatorsConfirmInteractorInputProtocol

    private(set) var priceData: PriceData?
    private(set) var balance: Decimal?

    let logger: LoggerProtocol?
    let viewModelFactory: SelectValidatorsConfirmViewModelFactoryProtocol
    let viewModelState: SelectValidatorsConfirmViewModelState
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let chainAsset: ChainAsset

    init(
        interactor: SelectValidatorsConfirmInteractorInputProtocol,
        wireframe: SelectValidatorsConfirmWireframeProtocol,
        viewModelFactory: SelectValidatorsConfirmViewModelFactoryProtocol,
        viewModelState: SelectValidatorsConfirmViewModelState,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        chainAsset: ChainAsset,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.viewModelState = viewModelState
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
        self.chainAsset = chainAsset
    }

    private func handle(error: Error) {
        let locale = view?.localizationManager?.selectedLocale

        if let confirmError = error as? SelectValidatorsConfirmError {
            guard let view = view else {
                return
            }

            switch confirmError {
            case .notEnoughFunds:
                wireframe.presentAmountTooHigh(from: view, locale: locale)
            case .feeNotReceived:
                wireframe.presentFeeNotReceived(from: view, locale: locale)
            case let .missingController(address):
                wireframe.presentMissingController(from: view, address: address, locale: locale)
            case .extrinsicFailed:
                wireframe.presentExtrinsicFailed(from: view, locale: locale)
            }
        } else {
            if !wireframe.present(error: error, from: view, locale: locale) {
                logger?.error("Did receive error: \(error)")
            }
        }
    }
}

extension SelectValidatorsConfirmPresenter: SelectValidatorsConfirmPresenterProtocol {
    func setup() {
        viewModelState.setStateListener(self)
        provideFee(viewModelState: viewModelState)

        interactor.setup()
        interactor.estimateFee(closure: viewModelState.createExtrinsicBuilderClosure())
    }

    func selectWalletAccount() {
        guard let walletAddress = viewModelState.walletAccountAddress else {
            return
        }

        if let view = view {
            let locale = view.localizationManager?.selectedLocale ?? Locale.current

            wireframe.presentAccountOptions(
                from: view,
                address: walletAddress,
                chain: chainAsset.chain,
                locale: locale
            )
        }
    }

    func selectPayoutAccount() {
        guard let address = viewModelState.payoutAccountAddress else {
            return
        }

        if let view = view {
            let locale = view.localizationManager?.selectedLocale ?? Locale.current

            wireframe.presentAccountOptions(
                from: view,
                address: address,
                chain: chainAsset.chain,
                locale: locale
            )
        }
    }

    func selectCollatorAccount() {
        guard let address = viewModelState.collatorAddress else {
            return
        }

        if let view = view {
            let locale = view.localizationManager?.selectedLocale ?? Locale.current

            wireframe.presentAccountOptions(
                from: view,
                address: address,
                chain: chainAsset.chain,
                locale: locale
            )
        }
    }

    func proceed() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        let customValidators: [DataValidating] = viewModelState.validators(using: locale)
        let commonValidators: [DataValidating] = [
            dataValidatingFactory.has(fee: viewModelState.fee, locale: locale) { [weak self] in
                self?.feeParametersUpdated()
            }
        ]

        DataValidationRunner(validators: customValidators + commonValidators).runValidation { [weak self] in
            self?.interactor.submitNomination(closure: self?.viewModelState.createExtrinsicBuilderClosure())
        }
    }
}

extension SelectValidatorsConfirmPresenter: SelectValidatorsConfirmInteractorOutputProtocol {
    func didReceivePrice(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideAsset(viewModelState: viewModelState)
            provideFee(viewModelState: viewModelState)
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            if let availableValue = accountInfo?.data.stakingAvailable {
                balance = Decimal.fromSubstrateAmount(
                    availableValue,
                    precision: Int16(chainAsset.asset.precision)
                )
            } else {
                balance = 0.0
            }

            provideAsset(viewModelState: viewModelState)
        case let .failure(error):
            didReceiveError(error: error)
        }
    }
}

extension SelectValidatorsConfirmPresenter: SelectValidatorsConfirmModelStateListener {
    func feeParametersUpdated() {
        interactor.estimateFee(closure: viewModelState.createExtrinsicBuilderClosure())
    }

    func didReceiveError(error: Error) {
        handle(error: error)
    }

    func provideConfirmationState(viewModelState: SelectValidatorsConfirmViewModelState) {
        guard let viewModel = try? viewModelFactory.buildViewModel(
            viewModelState: viewModelState
        ) else {
            return
        }

        view?.didReceive(confirmationViewModel: viewModel)

        provideAsset(viewModelState: viewModelState)
    }

    func provideHints(viewModelState: SelectValidatorsConfirmViewModelState) {
        guard let viewModel = viewModelFactory.buildHintsViewModel(viewModelState: viewModelState) else {
            return
        }

        view?.didReceive(hintsViewModel: viewModel)
    }

    func provideFee(viewModelState: SelectValidatorsConfirmViewModelState) {
        guard let viewModel = viewModelFactory.buildFeeViewModel(viewModelState: viewModelState, priceData: priceData) else {
            view?.didReceive(feeViewModel: nil)
            return
        }

        view?.didReceive(feeViewModel: viewModel)
    }

    func provideAsset(viewModelState: SelectValidatorsConfirmViewModelState) {
        guard
            let viewModel = viewModelFactory.buildAssetBalanceViewModel(
                viewModelState: viewModelState,
                priceData: priceData,
                balance: balance
            ) else {
            return
        }

        view?.didReceive(assetViewModel: viewModel)
    }

    func didStartNomination() {
        view?.didStartLoading()
    }

    func didCompleteNomination(txHash: String) {
        logger?.info("Did send nomination: \(txHash)")

        view?.didStopLoading()

        wireframe.complete(chainAsset: chainAsset, txHash: txHash, from: view)
    }

    func didFailNomination(error: Error) {
        view?.didStopLoading()

        handle(error: error)
    }
}
