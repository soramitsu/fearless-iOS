import Foundation
import SoraFoundation

final class ValidatorInfoWireframe: ValidatorInfoWireframeProtocol {
    func showStakingAmounts(
        from view: ValidatorInfoViewProtocol?,
        items: [LocalizableResource<StakingAmountViewModel>]
    ) {
        let maybeManageView = ModalPickerFactory.createPickerForList(
            items,
            delegate: nil,
            context: nil
        )
        guard let manageView = maybeManageView else { return }

        view?.controller.present(manageView, animated: true, completion: nil)
    }
}
