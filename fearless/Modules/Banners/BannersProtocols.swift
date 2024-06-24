typealias BannersModuleCreationResult = (
    view: BannersViewInput,
    input: BannersModuleInput
)

protocol BannersRouterInput: AnyObject, SheetAlertPresentable {
    func showWalletBackupScreen(
        for wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    )

    func presentLiquidityPools(
        on view: ControllerBackedProtocol?,
        wallet: MetaAccountModel
    )
}

protocol BannersModuleInput: AnyObject {
    func reload(with wallet: MetaAccountModel)
    func update(banners: [Banners])
}

protocol BannersModuleOutput: AnyObject {
    func reloadBannersView()
    func didTapCloseBanners()
}
