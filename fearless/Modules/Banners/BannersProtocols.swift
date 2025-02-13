import SSFModels

typealias BannersModuleCreationResult = (
    view: BannersViewInput,
    input: BannersModuleInput
)

protocol BannersRouterInput: AnyObject, SheetAlertPresentable, AccountManagementPresentable {
    func showWalletBackupScreen(
        for wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    )

    func presentLiquidityPools(
        on view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainId: ChainModel.Id
    )
    
    func showSoraCard(
        on view: ControllerBackedProtocol?
    )
    
    func showBuyXor(on view: ControllerBackedProtocol?)
}

protocol BannersModuleInput: AnyObject {
    func reload(with wallet: MetaAccountModel)
    func update(banners: [Banners])
    func reload()
}

protocol BannersModuleOutput: AnyObject {
    func reloadBannersView(bannersCount: Int)
    func didTapCloseBanners()
}
