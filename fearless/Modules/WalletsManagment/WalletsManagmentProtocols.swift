import Foundation
typealias WalletsManagmentModuleCreationResult = (view: WalletsManagmentViewInput, input: WalletsManagmentModuleInput)

protocol WalletsManagmentViewInput: ControllerBackedProtocol {
    func didReceiveViewModels(_ viewModels: [WalletsManagmentCellViewModel])
}

protocol WalletsManagmentViewOutput: AnyObject {
    func didLoad(view: WalletsManagmentViewInput)
    func didTapNewWallet()
    func didTapImportWallet()
    func didTapOptions(for indexPath: IndexPath)
    func didTapClose()
    func didTap(on indexPath: IndexPath)
}

protocol WalletsManagmentInteractorInput: AnyObject {
    func setup(with output: WalletsManagmentInteractorOutput)
    func select(wallet: ManagedMetaAccountModel)
}

protocol WalletsManagmentInteractorOutput: AnyObject {
    func didReceiveWallets(_ wallets: Result<[ManagedMetaAccountModel], Error>)
    func didReceiveWalletBalances(_ balances: Result<[MetaAccountId: WalletBalanceInfo], Error>)
    func didReceive(error: Error)
    func didCompleteSelection()
}

protocol WalletsManagmentRouterInput: AlertPresentable, ErrorPresentable {
    func showOptions(
        from view: WalletsManagmentViewInput?,
        metaAccount: ManagedMetaAccountModel
    )
    func dissmis(
        view: WalletsManagmentViewInput?,
        dissmisCompletion: @escaping () -> Void
    )
}

protocol WalletsManagmentModuleInput: AnyObject {}

protocol WalletsManagmentModuleOutput: AnyObject {
    func showAddNewWallet()
    func showImportWallet()
}
