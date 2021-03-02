import Foundation
import CommonWallet
import BigInt

final class StakingConfirmPresenter {
    weak var view: StakingConfirmViewProtocol?
    var wireframe: StakingConfirmWireframeProtocol!
    var interactor: StakingConfirmInteractorInputProtocol!

    private var balance: Decimal?
    private var priceData: PriceData?

    let state: PreparedNomination
    let asset: WalletAsset
    let walletAccount: AccountItem
    let logger: LoggerProtocol?
    let confirmationViewModelFactory: StakingConfirmViewModelFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    init(state: PreparedNomination,
         asset: WalletAsset,
         walletAccount: AccountItem,
         confirmationViewModelFactory: StakingConfirmViewModelFactoryProtocol,
         balanceViewModelFactory: BalanceViewModelFactoryProtocol,
         logger: LoggerProtocol?) {
        self.state = state
        self.asset = asset
        self.walletAccount = walletAccount
        self.confirmationViewModelFactory = confirmationViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.logger = logger
    }

    private func provideConfirmationState() {
        do {
            let viewModel = try confirmationViewModelFactory
                .createViewModel(from: state, walletAccount: walletAccount)
            view?.didReceive(confirmationViewModel: viewModel)
        } catch {
            logger?.error("Did receive error: \(error)")
        }
    }

    private func provideFee() {
        let viewModel = balanceViewModelFactory.balanceFromPrice(state.fee, priceData: priceData)
        view?.didReceive(feeViewModel: viewModel)
    }

    private func provideAsset() {
        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(state.amount,
                                                                            balance: balance,
                                                                            priceData: priceData)
        view?.didReceive(assetViewModel: viewModel)
    }

    private func handle(error: Error) {
        let locale = view?.localizationManager?.selectedLocale

        if !wireframe.present(error: error, from: view, locale: locale) {
            logger?.error("Did receive error: \(error)")
        }
    }
}

extension StakingConfirmPresenter: StakingConfirmPresenterProtocol {
    func setup() {
        provideConfirmationState()
        provideAsset()
        provideFee()

        interactor.setup()
    }

    func selectWalletAccount() {
        if let view = view, let chain = WalletAssetId(rawValue: asset.identifier)?.chain {
            let locale = view.localizationManager?.selectedLocale ?? Locale.current

            wireframe.presentAccountOptions(from: view,
                                            address: walletAccount.address,
                                            chain: chain,
                                            locale: locale)
        }
    }

    func selectPayoutAccount() {
        if case .payout(let account) = state.rewardDestination,
           let view = view,
           let chain = WalletAssetId(rawValue: asset.identifier)?.chain {
            let locale = view.localizationManager?.selectedLocale ?? Locale.current

            wireframe.presentAccountOptions(from: view,
                                            address: account.address,
                                            chain: chain,
                                            locale: locale)
        }
    }

    func proceed() {
        guard let balance = balance else {
            return
        }

        guard state.amount + state.fee <= balance else {
            return
        }

        guard let amount = state.amount.toSubstrateAmount(precision: asset.precision) else {
            return
        }

        interactor.submitNomination(controller: walletAccount,
                                    amount: amount,
                                    rewardDestination: state.rewardDestination,
                                    targets: state.targets)
    }
}

extension StakingConfirmPresenter: StakingConfirmInteractorOutputProtocol {
    func didReceive(price: PriceData?) {
        self.priceData = price
        provideAsset()
        provideFee()
    }

    func didReceive(priceError: Error) {
        handle(error: priceError)
    }

    func didReceive(balance: DyAccountData?) {
        if let availableValue = balance?.available {
            self.balance = Decimal.fromSubstrateAmount(availableValue,
                                                       precision: asset.precision)
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
}
