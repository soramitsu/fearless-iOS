import Foundation
import SoraFoundation
import FearlessUtils
import SoraKeystore

final class StakingMainViewFactory: StakingMainViewFactoryProtocol {
    static func createView() -> StakingMainViewProtocol? {
        let settings = SettingsManager.shared

        let view = StakingMainViewController(nib: R.nib.stakingMainViewController)
        let presenter = StakingMainPresenter()
        let interactor = StakingMainInteractor(settings: settings, eventCenter: EventCenter.shared)
        let wireframe = StakingMainWireframe()

        view.localizationManager = LocalizationManager.shared
        view.iconGenerator = PolkadotIconGenerator()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
