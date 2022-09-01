import Foundation
import SoraFoundation

// swiftlint:disable type_name
typealias StakingPoolJoinChoosePoolModuleCreationResult = (
    view: StakingPoolJoinChoosePoolViewInput,
    input: StakingPoolJoinChoosePoolModuleInput
)

protocol StakingPoolJoinChoosePoolViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(cellViewModels: [StakingPoolListTableCellModel])
    func didReceive(locale: Locale)
}

protocol StakingPoolJoinChoosePoolViewOutput: AnyObject {
    func didLoad(view: StakingPoolJoinChoosePoolViewInput)
    func didTapBackButton()
    func didTapContinueButton()
    func didTapOptionsButton()
}

protocol StakingPoolJoinChoosePoolInteractorInput: AnyObject {
    func setup(with output: StakingPoolJoinChoosePoolInteractorOutput)
}

protocol StakingPoolJoinChoosePoolInteractorOutput: AnyObject {
    func didReceivePools(_ pools: [StakingPool]?)
    func didReceiveError(_ error: Error)
}

protocol StakingPoolJoinChoosePoolRouterInput: PushDismissable, ErrorPresentable, AlertPresentable {
    func presentConfirm(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        inputAmount: Decimal,
        selectedPool: StakingPool
    )

    func presentOptions(
        options: [SortPickerTableViewCellModel],
        callback: ModalPickerSelectionCallback?,
        from view: ControllerBackedProtocol?
    )

    func presentPoolInfo(
        stakingPool: StakingPool,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    )
}

protocol StakingPoolJoinChoosePoolModuleInput: AnyObject {}

protocol StakingPoolJoinChoosePoolModuleOutput: AnyObject {}
