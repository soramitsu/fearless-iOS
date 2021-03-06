import Foundation
import SoraFoundation

final class SelectedValidatorsViewFactory: SelectedValidatorsViewFactoryProtocol {
    static func createView(for validators: [SelectedValidatorInfo]) -> SelectedValidatorsViewProtocol? {
        let view = SelectedValidatorsViewController(nib: R.nib.selectedValidatorsViewController)
        let presenter = SelectedValidatorsPresenter(validators: validators,
                                                    logger: Logger.shared)
        let wireframe = SelectedValidatorsWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe

        view.localizationManager = LocalizationManager.shared

        return view
    }
}
