import Foundation
import SoraFoundation

final class StakingRewardDetailsViewFactory: StakingRewardDetailsViewFactoryProtocol {

    static func createView() -> StakingRewardDetailsViewProtocol? {
        let presenter = StakingRewardDetailsPresenter()
        let view = StakingRewardDetailsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared)
        let interactor = StakingRewardDetailsInteractor()
        let wireframe = StakingRewardDetailsWireframe()

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
