import SoraFoundation
import SSFModels

protocol SelectedValidatorListViewProtocol: ControllerBackedProtocol, Localizable {
    func didReload(_ viewModel: SelectedValidatorListViewModel)
    func didChangeViewModel(
        _ viewModel: SelectedValidatorListViewModel,
        byRemovingItemAt index: Int
    )
}

protocol SelectedValidatorListDelegate: AnyObject {
    func didRemove(validatorAddress: AccountAddress)
    func didRemove(_ validator: SelectedValidatorInfo)
}

protocol SelectedValidatorListPresenterProtocol: AnyObject {
    func setup()
    func didSelectValidator(at index: Int)
    func removeItem(at index: Int)
    func proceed()
    func dismiss()
}

protocol SelectedValidatorListWireframeProtocol: SheetAlertPresentable, ErrorPresentable {
    func present(
        flow: ValidatorInfoFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    )

    func proceed(
        from _: SelectedValidatorListViewProtocol?,
        flow _: SelectValidatorsConfirmFlow,
        wallet _: MetaAccountModel,
        chainAsset _: ChainAsset
    )

    func dismiss(_ view: ControllerBackedProtocol?)
}

protocol SelectedValidatorListViewFactoryProtocol {
    static func createView(
        flow: SelectedValidatorListFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        delegate: SelectedValidatorListDelegate
    ) -> SelectedValidatorListViewProtocol?
}
