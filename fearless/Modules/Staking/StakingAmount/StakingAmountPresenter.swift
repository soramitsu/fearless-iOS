import Foundation
import CommonWallet
import BigInt

final class StakingAmountPresenter {
    weak var view: StakingAmountViewProtocol?
    var wireframe: StakingAmountWireframeProtocol!
    var interactor: StakingAmountInteractorInputProtocol!

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let rewardDestViewModelFactory: RewardDestinationViewModelFactoryProtocol
    let selectedAccount: AccountItem
    let logger: LoggerProtocol

    private var priceData: PriceData?
    private var balance: Decimal?
    private var fee: Decimal?
    private var asset: WalletAsset

    private var calculatedReward = CalculatedReward(restakeReturn: 4.12,
                                                    restakeReturnPercentage: 0.3551,
                                                    payoutReturn: 2.15,
                                                    payoutReturnPercentage: 0.2131)

    init(asset: WalletAsset,
         selectedAccount: AccountItem,
         rewardDestViewModelFactory: RewardDestinationViewModelFactoryProtocol,
         balanceViewModelFactory: BalanceViewModelFactoryProtocol,
         logger: LoggerProtocol) {
        self.asset = asset
        self.selectedAccount = selectedAccount
        self.rewardDestViewModelFactory = rewardDestViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.logger = logger
    }

    private func providePayoutRewardDestination() {
        do {
            let viewModel = try rewardDestViewModelFactory
                .createPayout(from: calculatedReward, account: selectedAccount)
            view?.didReceiveRewardDestination(viewModel: viewModel)
        } catch {
            logger.error("Can't create reward destination")
        }
    }

    private func provideRestakeRewardDestination() {
        do {
            let viewModel = try rewardDestViewModelFactory.createRestake(from: calculatedReward)
            view?.didReceiveRewardDestination(viewModel: viewModel)
        } catch {
            logger.error("Can't create reward destination")
        }
    }

    private func provideAmountPrice() {
        if let priceData = priceData {
            let price = balanceViewModelFactory.priceFromAmount(1.0, priceData: priceData)
            view?.didReceiveAmountPrice(viewModel: price)
        }
    }

    private func provideBalance() {
        let balanceViewModel = balanceViewModelFactory.amountFromValue(balance ?? 0.0)
        view?.didReceiveBalance(viewModel: balanceViewModel)
    }

    private func provideFee() {
        if let fee = fee {
            let feeViewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
            view?.didReceiveFee(viewModel: feeViewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }
}

extension StakingAmountPresenter: StakingAmountPresenterProtocol {
    func setup() {
        interactor.setup()
        provideRestakeRewardDestination()

        if let amount = Decimal(1.0).toSubstrateAmount(precision: asset.precision) {
            interactor.estimateFee(for: selectedAccount.address,
                                   amount: amount,
                                   rewardDestination: .restake)
        }
    }

    func selectRestakeDestination() {
        provideRestakeRewardDestination()
    }

    func selectPayoutDestination() {
        providePayoutRewardDestination()
    }

    func selectAmountPercentage(_ percentage: Float) {

    }

    func selectPayoutAccount() {

    }

    func close() {
        wireframe.close(view: view)
    }
}

extension StakingAmountPresenter: StakingAmountInteractorOutputProtocol {
    func didReceive(accounts: [ManagedAccountItem]) {}

    func didReceive(price: PriceData?) {
        self.priceData = price
        provideAmountPrice()
        provideFee()
    }

    func didReceive(balance: DyAccountData?) {
        if let availableValue = balance?.available,
           let available = Decimal.fromSubstrateAmount(availableValue,
                                                       precision: asset.precision) {
            self.balance = available
        } else {
            self.balance = nil
        }

        provideBalance()
    }

    func didReceive(paymentInfo: RuntimeDispatchInfo,
                    for amount: BigUInt,
                    rewardDestination: RewardDestination) {
        if let feeValue = BigUInt(paymentInfo.fee),
           let fee = Decimal.fromSubstrateAmount(feeValue, precision: asset.precision) {
            self.fee = fee
        } else {
            self.fee = nil
        }

        provideFee()
    }

    func didReceive(error: Error) {
        logger.error("Did receive error: \(error)")
    }
}
