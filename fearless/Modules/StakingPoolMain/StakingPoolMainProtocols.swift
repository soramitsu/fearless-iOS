typealias StakingPoolMainModuleCreationResult = (view: StakingPoolMainViewInput, input: StakingPoolMainModuleInput)

protocol StakingPoolMainViewInput: ControllerBackedProtocol {
    func didReceiveBalanceViewModel(_ balanceViewModel: BalanceViewModelProtocol)
    func didReceiveChainAsset(_ chainAsset: ChainAsset)
}

protocol StakingPoolMainViewOutput: AnyObject {
    func didLoad(view: StakingPoolMainViewInput)
    func performAssetSelection()
}

protocol StakingPoolMainInteractorInput: AnyObject {
    func setup(with output: StakingPoolMainInteractorOutput)
    func updateWithChainAsset(_ chainAsset: ChainAsset)
    func save(chainAsset: ChainAsset)
}

protocol StakingPoolMainInteractorOutput: AnyObject {
    func didReceive(accountInfo: AccountInfo?)
    func didReceive(balanceError: Error)
    func didReceive(chainAsset: ChainAsset)
}

protocol StakingPoolMainRouterInput: AnyObject {
    func showChainAssetSelection(
        from view: StakingPoolMainViewInput?,
        type: AssetSelectionStakingType,
        delegate: AssetSelectionDelegate
    )
}

protocol StakingPoolMainModuleInput: AnyObject {}

protocol StakingPoolMainModuleOutput: AnyObject {}
