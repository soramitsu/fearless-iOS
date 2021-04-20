import Foundation
import IrohaCrypto
import FearlessUtils

final class StakingRewardDetailsPresenter {
    weak var view: StakingRewardDetailsViewProtocol?
    var wireframe: StakingRewardDetailsWireframeProtocol!
    var interactor: StakingRewardDetailsInteractorInputProtocol!

    private let payoutInfo: PayoutInfo
    private let chain: Chain
    private let viewModelFactory: StakingRewardDetailsViewModelFactoryProtocol

    init(
        payoutInfo: PayoutInfo,
        chain: Chain,
        viewModelFactory: StakingRewardDetailsViewModelFactoryProtocol
    ) {
        self.payoutInfo = payoutInfo
        self.chain = chain
        self.viewModelFactory = viewModelFactory
    }
}

extension StakingRewardDetailsPresenter: StakingRewardDetailsPresenterProtocol {
    func setup() {
        let viewModel = viewModelFactory.createViewModel()
        view?.reload(with: viewModel)
    }

    func handlePayoutAction() {
        wireframe.showPayoutConfirmation(from: view, payoutInfo: payoutInfo)
    }

    func handleValidatorAccountAction() {
        guard
            let view = view,
            let address = viewModelFactory.validatorAddress
        else { return }
        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: .autoupdatingCurrent
        )
    }
}

extension StakingRewardDetailsPresenter: StakingRewardDetailsInteractorOutputProtocol {}
