
import SSFModels
typealias SelectExportAccountModuleCreationResult = (view: SelectExportAccountViewInput, input: SelectExportAccountModuleInput)

protocol SelectExportAccountViewInput: ControllerBackedProtocol {
    func didReceive(state: SelectExportAccountViewState)
}

protocol SelectExportAccountViewOutput: AnyObject {
    func didLoad(view: SelectExportAccountViewInput)
    func exportNativeAccounts()
}

protocol SelectExportAccountInteractorInput: AnyObject {
    func setup(with output: SelectExportAccountInteractorOutput)
}

protocol SelectExportAccountInteractorOutput: AnyObject {
    func didReceive(chains: [ChainModel])
}

protocol SelectExportAccountRouterInput: AnyObject {
    func showWalletDetails(
        selectedWallet: MetaAccountModel,
        accountsInfo: [ChainAccountInfo],
        from view: ControllerBackedProtocol?
    )
}

protocol SelectExportAccountModuleInput: AnyObject {}

protocol SelectExportAccountModuleOutput: AnyObject {}
