import Foundation
import SoraFoundation

final class StakingRewardDetailsViewFactory: StakingRewardDetailsViewFactoryProtocol {
    static func createView(payoutItem: StakingPayoutItem) -> StakingRewardDetailsViewProtocol? {
        let presenter = StakingRewardDetailsPresenter()
        let view = StakingRewardDetailsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )
        let interactor = StakingRewardDetailsInteractor(payoutItem: payoutItem)
        let wireframe = StakingRewardDetailsWireframe()

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
