typealias BannersModuleCreationResult = (
    view: BannersViewInput,
    input: BannersModuleInput
)

protocol BannersRouterInput: AnyObject, SheetAlertPresentable {
    func showWalletBackupScreen(
        for wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    )
}

protocol BannersModuleInput: AnyObject {
    func reload(with wallet: MetaAccountModel)
}

protocol BannersModuleOutput: AnyObject {
    func reloadBannersView()
}
