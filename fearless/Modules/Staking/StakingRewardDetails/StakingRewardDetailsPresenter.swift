import Foundation

final class StakingRewardDetailsPresenter {
    weak var view: StakingRewardDetailsViewProtocol?
    var wireframe: StakingRewardDetailsWireframeProtocol!
    var interactor: StakingRewardDetailsInteractorInputProtocol!

    private func createViewModel(payoutItem: StakingPayoutItem) -> StakingRewardDetailsViewModel {
        let tokenAmount = payoutItem.reward.description
        let rows: [RewardDetailsRow] = [
            .validatorInfo(.init(
                name: "Validator",
                address: "✨👍✨ Day7 ✨👍✨",
                icon: R.image.iconAccount()
            )),
            .date(.init(
                titleText: R.string.localizable.stakingRewardDetailsDate(),
                valueText: "Feb 2, 2021"
            )),
            .era(.init(
                titleText: R.string.localizable.stakingRewardDetailsEra(),
                valueText: "#\(payoutItem.era.description)"
            )),
            .reward(.init(ksmAmountText: tokenAmount, usdAmountText: "$0"))
        ]
        return .init(rows: rows)
    }
}

extension StakingRewardDetailsPresenter: StakingRewardDetailsPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func handlePayoutAction() {
        wireframe.showPayoutConfirmation(from: view)
    }
}

extension StakingRewardDetailsPresenter: StakingRewardDetailsInteractorOutputProtocol {
    func didRecieve(payoutItem: StakingPayoutItem) {
        let viewModel = createViewModel(payoutItem: payoutItem)
        view?.reload(with: viewModel)
    }
}
