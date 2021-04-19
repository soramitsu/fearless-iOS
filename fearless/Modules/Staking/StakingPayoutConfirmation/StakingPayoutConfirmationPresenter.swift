import Foundation
import BigInt
import CommonWallet

final class StakingPayoutConfirmationPresenter {
    weak var view: StakingPayoutConfirmationViewProtocol?
    var wireframe: StakingPayoutConfirmationWireframeProtocol!
    var interactor: StakingPayoutConfirmationInteractorInputProtocol!

    private var fee: Decimal?
    private var priceData: PriceData?
    private var balance: Decimal?

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let logger: LoggerProtocol?
    let asset: WalletAsset

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        asset: WalletAsset,
        logger: LoggerProtocol? = nil
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.asset = asset
        self.logger = logger
    }
}

extension StakingPayoutConfirmationPresenter: StakingPayoutConfirmationPresenterProtocol {
    func setup() {
        provideFee()

        interactor.setup()
        interactor.estimateFee()
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

        interactor.submitPayout(for: balance ?? 0.0, lastFee: fee)
    }

    // MARK: - Private functions

    private func provideFee() {
        if let fee = fee {
            let viewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
            view?.didReceive(feeViewModel: viewModel)
        } else {
            view?.didReceive(feeViewModel: nil)
        }
    }

    private func handle(error: Error) {
        let locale = view?.localizationManager?.selectedLocale

        if let confirmError = error as? StakingConfirmError {
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

extension StakingPayoutConfirmationPresenter: StakingPayoutConfirmationInteractorOutputProtocol {
    func didStartPayout() {
        view?.didStartLoading()
    }

    func didCompletePayout(txHash: String) {
        logger?.info("Did send payouts: \(txHash)")

        view?.didStopLoading()

        wireframe.complete(from: view)
    }

    func didFailPayout(error: Error) {
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

    func didReceive(balance: DyAccountData?) {
        if let availableValue = balance?.available {
            self.balance = Decimal.fromSubstrateAmount(
                availableValue,
                precision: asset.precision
            )
        } else {
            self.balance = 0.0
        }
    }

    func didReceive(balanceError: Error) {
        handle(error: balanceError)
    }
}
