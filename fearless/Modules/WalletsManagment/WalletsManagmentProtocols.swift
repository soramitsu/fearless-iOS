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
    func fetchWalletsFromRepo()
}

protocol WalletsManagmentInteractorOutput: AnyObject {
    func didReceiveWallets(_ wallets: Result<[ManagedMetaAccountModel], Error>)
    func didReceiveWalletBalances(_ balances: Result<[MetaAccountId: WalletBalanceInfo], Error>)
    func didReceive(error: Error)
    func didCompleteSelection()
    func didReceiveFeatureToggleConfig(result: Result<FeatureToggleConfig, Error>?)
}

protocol WalletsManagmentRouterInput: SheetAlertPresentable, ErrorPresentable {
    func showOptions(
        from view: WalletsManagmentViewInput?,
        metaAccount: ManagedMetaAccountModel,
        delegate: WalletOptionModuleOutput?
    )
    func dissmis(
        view: WalletsManagmentViewInput?,
        dissmisCompletion: @escaping () -> Void
    )
}

protocol WalletsManagmentModuleInput: AnyObject {}

protocol WalletsManagmentModuleOutput: AnyObject {
    func showAddNewWallet()
    func showImportWallet(defaultSource: AccountImportSource)
    func showImportGoogle()
    func showGetPreinstalledWallet()
    func selectedWallet(_ wallet: MetaAccountModel, for contextTag: Int)
}

extension WalletsManagmentModuleOutput {
    func showAddNewWallet() {}
    func showImportWallet(defaultSource _: AccountImportSource) {}
    func showImportGoogle() {}
    func selectedWallet(_: MetaAccountModel, for _: Int) {}
    func showGetPreinstalledWallet() {}
}
