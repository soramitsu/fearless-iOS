import SoraFoundation
import SSFModels

protocol StakingBalanceViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func reload(with viewModel: LocalizableResource<StakingBalanceViewModel>)
}

protocol StakingBalancePresenterProtocol: AnyObject {
    func setup()
    func handleRefresh()
    func handleAction(_ action: StakingBalanceAction)
    func handleUnbondingMoreAction()
}

protocol StakingBalanceInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
}

protocol StakingBalanceInteractorOutputProtocol: AnyObject {}

protocol StakingBalanceWireframeProtocol: SheetAlertPresentable, ErrorPresentable, StakingErrorPresentable {
    func showBondMore(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingBondMoreFlow
    )

    func showUnbond(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingUnbondSetupFlow
    )

    func showRedeem(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingRedeemConfirmationFlow
    )

    func showRebondSetup(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )

    func showRebondConfirm(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingRebondConfirmationFlow
    )

    func cancel(from view: ControllerBackedProtocol?)
}
