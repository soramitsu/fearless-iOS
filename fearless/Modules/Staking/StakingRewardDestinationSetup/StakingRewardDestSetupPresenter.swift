import Foundation
import BigInt
import SoraFoundation

final class StakingRewardDestSetupPresenter {
    weak var view: StakingRewardDestSetupViewProtocol?

    let wireframe: StakingRewardDestSetupWireframeProtocol
    let interactor: StakingRewardDestSetupInteractorInputProtocol
    let rewardDestViewModelFactory: RewardDestinationViewModelFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let applicationConfig: ApplicationConfigProtocol
    let chain: Chain
    let logger: LoggerProtocol?

    private var rewardDestination: RewardDestination<AccountItem> = .restake
    private var calculator: RewardCalculatorEngineProtocol?
    private var electionStatus: ElectionStatus?
    private var payee: RewardDestinationArg?
    private var payoutAccount: AccountItem
    private var controller: AccountItem?
    private var priceData: PriceData?
    private var stashItem: StashItem?
    private var amount: Decimal?
    private var fee: Decimal?

    init(
        wireframe: StakingRewardDestSetupWireframeProtocol,
        interactor: StakingRewardDestSetupInteractorInputProtocol,
        rewardDestViewModelFactory: RewardDestinationViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        payoutAccount: AccountItem,
        applicationConfig: ApplicationConfigProtocol,
        chain: Chain,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.rewardDestViewModelFactory = rewardDestViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.payoutAccount = payoutAccount
        self.applicationConfig = applicationConfig
        self.chain = chain
        self.logger = logger
    }

    // MARK: - Private functions

    private func refreshFeeIfNeeded() {
        guard fee == nil, controller != nil, payee != nil, amount != nil else {
            return
        }

        interactor.estimateFee()
    }

    private func provideRewardDestination() {
        do {
            let reward: CalculatedReward?

            if let calculator = calculator {
                let restake = try calculator.calculateNetworkReturn(
                    isCompound: true,
                    period: .year
                )

                let payout = try calculator.calculateNetworkReturn(
                    isCompound: false,
                    period: .year
                )

                let curAmount = amount ?? 0.0
                reward = CalculatedReward(
                    restakeReturn: restake * curAmount,
                    restakeReturnPercentage: restake,
                    payoutReturn: payout * curAmount,
                    payoutReturnPercentage: payout
                )
            } else {
                reward = nil
            }

            // TODO: Fill from presenter
            switch rewardDestination {
            case .restake:
                let viewModel = rewardDestViewModelFactory.createRestake(from: reward)
                view?.didReceiveRewardDestination(viewModel: viewModel)
            case let .payout(payoutAccount):
                let viewModel = try rewardDestViewModelFactory
                    .createPayout(from: reward, account: payoutAccount)
                view?.didReceiveRewardDestination(viewModel: viewModel)
            }
        } catch {
            logger?.error("Can't create reward destination")
        }
    }

    private func provideFeeViewModel() {
        if let fee = fee {
            let feeViewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
            view?.didReceiveFee(viewModel: feeViewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }
}

extension StakingRewardDestSetupPresenter: StakingRewardDestSetupPresenterProtocol {
    func setup() {
        provideRewardDestination()
        provideFeeViewModel()

        interactor.setup()
    }

    func selectRestakeDestination() {
        rewardDestination = .restake
        provideRewardDestination()
    }

    func selectPayoutDestination() {
        rewardDestination = .payout(account: payoutAccount)
        provideRewardDestination()
    }

    func selectPayoutAccount() {
        interactor.fetchPayoutAccounts()
    }

    func displayLearnMore() {
        if let view = view {
            wireframe.showWeb(
                url: applicationConfig.learnPayoutURL,
                from: view,
                style: .automatic
            )
        }
    }

    func proceed() {
        #warning("Not implemented")
    }
}

extension StakingRewardDestSetupPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard
            let accounts =
            (context as? PrimitiveContextWrapper<[AccountItem]>)?.value
        else {
            return
        }

        payoutAccount = accounts[index]

        if case .payout = rewardDestination {
            rewardDestination = .payout(account: payoutAccount)
        }

        provideRewardDestination()
    }
}

extension StakingRewardDestSetupPresenter: StakingRewardDestSetupInteractorOutputProtocol {
    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData
            provideFeeViewModel()

        case let .failure(error):
            logger?.error("Price data subscription error: \(error)")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            if let fee = BigUInt(dispatchInfo.fee) {
                self.fee = Decimal.fromSubstrateAmount(fee, precision: chain.addressType.precision)
            }

            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceiveStashItem(result: Result<StashItem?, Error>) {
        switch result {
        case let .success(stashItem):
            self.stashItem = stashItem
        case let .failure(error):
            logger?.error("Did receive stash item error: \(error)")
        }
    }

    func didReceiveController(result: Result<AccountItem?, Error>) {
        switch result {
        case let .success(accountItem):
            if let accountItem = accountItem {
                controller = accountItem
            }
        case let .failure(error):
            logger?.error("Did receive controller account error: \(error)")
        }
    }

    func didReceiveStakingLedger(result: Result<DyStakingLedger?, Error>) {
        switch result {
        case let .success(stakingLedger):
            if let stakingLedger = stakingLedger {
                amount = Decimal.fromSubstrateAmount(
                    stakingLedger.active,
                    precision: chain.addressType.precision
                )
            } else {
                amount = nil
            }

            provideRewardDestination()
        case let .failure(error):
            logger?.error("Staking ledger subscription error: \(error)")
        }
    }

    func didReceivePayee(result: Result<RewardDestinationArg?, Error>) {
        switch result {
        case let .success(payee):
            self.payee = payee

            refreshFeeIfNeeded()

            provideRewardDestination()
        case let .failure(error):
            logger?.error("Did receive payee item error: \(error)")
        }
    }

    func didReceiveCalculator(result: Result<RewardCalculatorEngineProtocol?, Error>) {
        switch result {
        case let .success(calculator):
            self.calculator = calculator

            provideRewardDestination()
        case let .failure(error):
            logger?.error("Did receive calculator error: \(error)")
        }
    }

    func didReceiveAccounts(result: Result<[AccountItem], Error>) {
        switch result {
        case let .success(accounts):
            let context = PrimitiveContextWrapper(value: accounts)

            wireframe.presentAccountSelection(
                accounts,
                selectedAccountItem: payoutAccount,
                delegate: self,
                from: view,
                context: context
            )

        case let .failure(error):
            logger?.error("Did receive accounts retrieval error: \(error)")
        }
    }

    func didReceiveElectionStatus(result: Result<ElectionStatus?, Error>) {
        switch result {
        case let .success(electionStatus):
            self.electionStatus = electionStatus
        case let .failure(error):
            logger?.error("Election status error: \(error)")
        }
    }
}
