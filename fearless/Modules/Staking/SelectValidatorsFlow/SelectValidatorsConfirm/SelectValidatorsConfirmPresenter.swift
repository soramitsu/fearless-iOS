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

    var state: SelectValidatorsConfirmationModel?
    let logger: LoggerProtocol?
    let confirmationViewModelFactory: SelectValidatorsConfirmViewModelFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let asset: WalletAsset

    init(
        confirmationViewModelFactory: SelectValidatorsConfirmViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        asset: WalletAsset,
        logger: LoggerProtocol? = nil
    ) {
        self.confirmationViewModelFactory = confirmationViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
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
        guard let fee = fee else {
            if let view = view {
                wireframe.presentFeeNotReceived(
                    from: view,
                    locale: view.localizationManager?.selectedLocale
                )
            }

            return
        }

        interactor.submitNomination(for: balance ?? 0.0, lastFee: fee)
    }
}

extension SelectValidatorsConfirmPresenter: SelectValidatorsConfirmInteractorOutputProtocol {
    func didReceive(model: SelectValidatorsConfirmationModel) {
        state = model

        provideAsset()
        provideConfirmationState()
    }

    func didReceive(modelError: Error) {
        handle(error: modelError)
    }

    func didReceive(price: PriceData?) {
        priceData = price
        provideAsset()
        provideFee()
    }

    func didReceive(priceError: Error) {
        handle(error: priceError)
    }

    func didReceive(balance: AccountData?) {
        if let availableValue = balance?.available {
            self.balance = Decimal.fromSubstrateAmount(
                availableValue,
                precision: asset.precision
            )
        } else {
            self.balance = 0.0
        }

        provideAsset()
    }

    func didReceive(balanceError: Error) {
        handle(error: balanceError)
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
