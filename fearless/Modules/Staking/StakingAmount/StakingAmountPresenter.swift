import Foundation

final class StakingAmountPresenter {
    weak var view: StakingAmountViewProtocol?
    var wireframe: StakingAmountWireframeProtocol!
    var interactor: StakingAmountInteractorInputProtocol!

    let rewardDestViewModelFactory: RewardDestinationViewModelFactoryProtocol

    let selectedAccount: AccountItem

    let logger: LoggerProtocol

    private var calculatedReward = CalculatedReward(restakeReturn: 4.12,
                                                    restakeReturnPercentage: 0.3551,
                                                    payoutReturn: 2.15,
                                                    payoutReturnPercentage: 0.2131)

    init(selectedAccount: AccountItem,
         rewardDestViewModelFactory: RewardDestinationViewModelFactoryProtocol,
         logger: LoggerProtocol) {
        self.selectedAccount = selectedAccount
        self.rewardDestViewModelFactory = rewardDestViewModelFactory
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
}

extension StakingAmountPresenter: StakingAmountPresenterProtocol {
    func setup() {
        provideRestakeRewardDestination()
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

    func didReceive(error: Error) {}
}
