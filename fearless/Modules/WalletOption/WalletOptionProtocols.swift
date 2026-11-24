typealias WalletOptionModuleCreationResult = (view: WalletOptionViewInput, input: WalletOptionModuleInput)

protocol WalletOptionViewInput: ControllerBackedProtocol {
    func setDeleteButtonIsVisible(_ isVisible: Bool)
}

protocol WalletOptionViewOutput: AnyObject {
    func didLoad(view: WalletOptionViewInput)
    func walletDetailsDidTap()
    func exportWalletDidTap()
    func deleteWalletDidTap()
    func changeWalletNameDidTap()
}

protocol WalletOptionInteractorInput: AnyObject {
    func setup(with output: WalletOptionInteractorOutput)
    func deleteWallet()
}

protocol WalletOptionInteractorOutput: AnyObject {
    func setDeleteButtonIsVisible(_ isVisible: Bool)
    func walletRemoved()
}

protocol WalletOptionRouterInput: SheetAlertPresentable, AnyDismissable {
    func showWalletDetails(
        from view: ControllerBackedProtocol?,
        for wallet: MetaAccountModel
    )
    func showExportWallet(
        from view: ControllerBackedProtocol?,
        wallet: ManagedMetaAccountModel
    )
    func showChangeWalletName(
        from view: ControllerBackedProtocol?,
        for wallet: MetaAccountModel
    )
}

protocol WalletOptionModuleInput: AnyObject {}

protocol WalletOptionModuleOutput: AnyObject {
    func walletWasRemoved()
}
