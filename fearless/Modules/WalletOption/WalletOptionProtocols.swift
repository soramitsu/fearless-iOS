typealias WalletOptionModuleCreationResult = (view: WalletOptionViewInput, input: WalletOptionModuleInput)

protocol WalletOptionViewInput: ControllerBackedProtocol {
    func setDeleteButtonIsVisible(_ isVisible: Bool)
}

protocol WalletOptionViewOutput: AnyObject {
    func didLoad(view: WalletOptionViewInput)
    func walletDetailsDidTap()
    func exportWalletDidTap()
    func deleteWalletDidTap()
}

protocol WalletOptionInteractorInput: AnyObject {
    func setup(with output: WalletOptionInteractorOutput)
    func deleteWallet()
}

protocol WalletOptionInteractorOutput: AnyObject {
    func setDeleteButtonIsVisible(_ isVisible: Bool)
    func walletRemoved()
}

protocol WalletOptionRouterInput: AlertPresentable {
    func showWalletDetails(
        from view: ControllerBackedProtocol?,
        for wallet: MetaAccountModel
    )
    func showExportWallet(
        from view: ControllerBackedProtocol?,
        wallet: ManagedMetaAccountModel
    )
    func dismiss(from view: ControllerBackedProtocol?)
}

protocol WalletOptionModuleInput: AnyObject {}

protocol WalletOptionModuleOutput: AnyObject {
    func walletWasRemoved()
}
