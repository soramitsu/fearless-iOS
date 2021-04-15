import Foundation

final class StakingPayoutConfirmationPresenter {
    weak var view: StakingPayoutConfirmationViewProtocol?
    var wireframe: StakingPayoutConfirmationWireframeProtocol!
    var interactor: StakingPayoutConfirmationInteractorInputProtocol!
}

extension StakingPayoutConfirmationPresenter: StakingPayoutConfirmationPresenterProtocol {
    func setup() {}
}

extension StakingPayoutConfirmationPresenter: StakingPayoutConfirmationInteractorOutputProtocol {
    func didStartPayout() {
        #warning("Not implemented")
    }

    func didCompletePayout(txHash _: String) {
        #warning("Not implemented")
    }

    func didFailPayout(error _: Error) {
        #warning("Not implemented")
    }

    func didReceive(paymentInfo _: RuntimeDispatchInfo) {
        #warning("Not implemented")
    }

    func didReceive(feeError _: Error) {
        #warning("Not implemented")
    }
}
