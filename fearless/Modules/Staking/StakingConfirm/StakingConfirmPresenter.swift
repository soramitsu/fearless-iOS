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
}

extension StakingConfirmPresenter: StakingConfirmPresenterProtocol {
    func setup() {
        provideConfirmationState()
        provideAsset()
        provideFee()

        interactor.setup()
    }

    func selectWalletAccount() {

    }

    func selectPayoutAccount() {

    }

    func proceed() {

    }
}

extension StakingConfirmPresenter: StakingConfirmInteractorOutputProtocol {
    func didReceive(price: PriceData?) {
        self.priceData = price
        provideAsset()
        provideFee()
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

    func didReceive(error: Error) {
        let locale = view?.localizationManager?.selectedLocale

        if !wireframe.present(error: error, from: view, locale: locale) {
            logger?.error("Did receive error: \(error)")
        }
    }
}
