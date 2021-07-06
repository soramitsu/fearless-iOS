import Foundation
import CommonWallet
import BigInt

final class SelectValidatorsConfirmPresenter {
    weak var view: SelectValidatorsConfirmViewProtocol?
    var wireframe: SelectValidatorsConfirmWireframeProtocol!
    var interactor: SelectValidatorsConfirmInteractorInputProtocol!

    private var balance: Decimal?
    private var priceData: PriceData?
    private var fee: Decimal?
    private var minimalBalance: Decimal?
    private var minNominatorBond: Decimal?
    private var counterForNominators: UInt32?
    private var maxNominatorsCount: UInt32?

    var state: SelectValidatorsConfirmationModel?
    let logger: LoggerProtocol?
    let confirmationViewModelFactory: SelectValidatorsConfirmViewModelFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let asset: WalletAsset

    init(
        confirmationViewModelFactory: SelectValidatorsConfirmViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        asset: WalletAsset,
        logger: LoggerProtocol? = nil
    ) {
        self.confirmationViewModelFactory = confirmationViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
        self.asset = asset
    }

    private func provideConfirmationState() {
        guard let state = state else {
            return
        }

        do {
            let viewModel = try confirmationViewModelFactory.createViewModel(from: state, asset: asset)
            view?.didReceive(confirmationViewModel: viewModel)
        } catch {
            logger?.error("Did receive error: \(error)")
        }
    }

    private func provideFee() {
        if let fee = fee {
            let viewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
            view?.didReceive(feeViewModel: viewModel)
        } else {
            view?.didReceive(feeViewModel: nil)
        }
    }

    private func provideAsset() {
        guard let state = state else {
            return
        }

        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            state.amount,
            balance: balance,
            priceData: priceData
        )
        view?.didReceive(assetViewModel: viewModel)
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
        provideFee()

        interactor.setup()
        interactor.estimateFee()
    }

    func selectWalletAccount() {
        guard let state = state else {
            return
        }

        if let view = view, let chain = WalletAssetId(rawValue: asset.identifier)?.chain {
            let locale = view.localizationManager?.selectedLocale ?? Locale.current

            wireframe.presentAccountOptions(
                from: view,
                address: state.wallet.address,
                chain: chain,
                locale: locale
            )
        }
    }

    func selectPayoutAccount() {
        guard let state = state else {
            return
        }

        if case let .payout(account) = state.rewardDestination,
           let view = view,
           let chain = WalletAssetId(rawValue: asset.identifier)?.chain {
            let locale = view.localizationManager?.selectedLocale ?? Locale.current

            wireframe.presentAccountOptions(
                from: view,
                address: account.address,
                chain: chain,
                locale: locale
            )
        }
    }

    func proceed() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: fee, locale: locale) { [weak self] in
                self?.interactor.estimateFee()
            },
            dataValidatingFactory.canNominate(
                amount: state?.amount,
                minimalBalance: minimalBalance,
                minNominatorBond: minNominatorBond,
                locale: locale
            ),
            dataValidatingFactory.maxNominatorsCountNotReached(
                counterForNominators: counterForNominators,
                maxNominatorsCount: maxNominatorsCount,
                locale: locale
            )
        ]).runValidation { [weak self] in
            guard let fee = self?.fee else {
                return
            }

            self?.interactor.submitNomination(for: self?.balance ?? 0.0, lastFee: fee)
        }
    }
}

extension SelectValidatorsConfirmPresenter: SelectValidatorsConfirmInteractorOutputProtocol {
    func didReceiveModel(result: Result<SelectValidatorsConfirmationModel, Error>) {
        switch result {
        case let .success(model):
            state = model

            provideAsset()
            provideConfirmationState()
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceivePrice(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideAsset()
            provideFee()
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            if let availableValue = accountInfo?.data.available {
                balance = Decimal.fromSubstrateAmount(
                    availableValue,
                    precision: asset.precision
                )
            } else {
                balance = 0.0
            }

            provideAsset()
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveMinBond(result: Result<BigUInt?, Error>) {
        switch result {
        case let .success(minBond):
            minNominatorBond = minBond.map {
                Decimal.fromSubstrateAmount($0, precision: asset.precision)
            } ?? nil
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveMaxNominatorsCount(result: Result<UInt32?, Error>) {
        switch result {
        case let .success(maxNominatorsCount):
            self.maxNominatorsCount = maxNominatorsCount
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveCounterForNominators(result: Result<UInt32?, Error>) {
        switch result {
        case let .success(counterForNominators):
            self.counterForNominators = counterForNominators
        case let .failure(error):
            handle(error: error)
        }
    }

    func didStartNomination() {
        view?.didStartLoading()
    }

    func didCompleteNomination(txHash: String) {
        logger?.info("Did send nomination: \(txHash)")

        view?.didStopLoading()

        wireframe.complete(from: view)
    }

    func didFailNomination(error: Error) {
        view?.didStopLoading()

        handle(error: error)
    }

    func didReceive(paymentInfo: RuntimeDispatchInfo) {
        if let feeValue = BigUInt(paymentInfo.fee),
           let fee = Decimal.fromSubstrateAmount(feeValue, precision: asset.precision) {
            self.fee = fee
        } else {
            fee = nil
        }

        provideFee()
    }

    func didReceive(feeError: Error) {
        handle(error: feeError)
    }
}
