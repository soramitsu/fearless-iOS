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
    let feeDebounce = 1.0

    private var priceData: PriceData?
    private var balance: Decimal?
    private var fee: Decimal?
    private var asset: WalletAsset
    private var amount: Decimal = 0.0
    private var rewardDestination: RewardDestination = .restake
    private var payoutAccount: AccountItem

    private lazy var scheduler: SchedulerProtocol = Scheduler(with: self, callbackQueue: .main)

    private var calculatedReward = CalculatedReward(restakeReturn: 4.12,
                                                    restakeReturnPercentage: 0.3551,
                                                    payoutReturn: 2.15,
                                                    payoutReturnPercentage: 0.2131)

    deinit {
        scheduler.cancel()
    }

    init(asset: WalletAsset,
         selectedAccount: AccountItem,
         rewardDestViewModelFactory: RewardDestinationViewModelFactoryProtocol,
         balanceViewModelFactory: BalanceViewModelFactoryProtocol,
         feeDebounce: TimeInterval = 2.0,
         logger: LoggerProtocol) {
        self.asset = asset
        self.selectedAccount = selectedAccount
        self.payoutAccount = selectedAccount
        self.rewardDestViewModelFactory = rewardDestViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.logger = logger
    }

    private func provideRewardDestination() {
        do {
            switch rewardDestination {
            case .restake:
                let viewModel = try rewardDestViewModelFactory.createRestake(from: calculatedReward)
                view?.didReceiveRewardDestination(viewModel: viewModel)
            case .payout:
                let viewModel = try rewardDestViewModelFactory
                    .createPayout(from: calculatedReward, account: payoutAccount)
                view?.didReceiveRewardDestination(viewModel: viewModel)
            }
        } catch {
            logger.error("Can't create reward destination")
        }
    }

    private func provideAmountPrice() {
        if let priceData = priceData {
            let price = balanceViewModelFactory.priceFromAmount(amount, priceData: priceData)
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

    private func provideAmountInputViewModel() {
        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(amount)
        view?.didReceiveInput(viewModel: viewModel)
    }

    private func scheduleFeeEstimation() {
        scheduler.cancel()
        scheduler.notifyAfter(feeDebounce)
    }

    private func estimateFee() {
        if let amount = amount.toSubstrateAmount(precision: asset.precision) {
            interactor.estimateFee(for: selectedAccount.address,
                                   amount: amount,
                                   rewardDestination: rewardDestination)
        }
    }
}

extension StakingAmountPresenter: StakingAmountPresenterProtocol {
    func setup() {
        provideAmountInputViewModel()
        provideRewardDestination()

        interactor.setup()

        estimateFee()
    }

    func selectRestakeDestination() {
        rewardDestination = .restake
        provideRewardDestination()

        scheduleFeeEstimation()
    }

    func selectPayoutDestination() {
        rewardDestination = .payout(address: payoutAccount.address)
        provideRewardDestination()

        scheduleFeeEstimation()
    }

    func selectAmountPercentage(_ percentage: Float) {
        if let balance = balance, let fee = fee {
            let newAmount = max(balance - fee, 0.0) * Decimal(Double(percentage))
            amount = newAmount

            provideAmountInputViewModel()
            provideAmountPrice()
        }
    }

    func selectPayoutAccount() {

    }

    func updateAmount(_ newValue: Decimal) {
        amount = newValue

        provideAmountPrice()
        
        scheduleFeeEstimation()
    }

    func close() {
        wireframe.close(view: view)
    }
}

extension StakingAmountPresenter: SchedulerDelegate {
    func didTrigger(scheduler: SchedulerProtocol) {
        estimateFee()
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
