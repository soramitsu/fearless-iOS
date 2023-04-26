typealias KYCMainModuleCreationResult = (view: KYCMainViewInput, input: KYCMainModuleInput)

protocol KYCMainViewInput: ControllerBackedProtocol {
    func set(viewModel: KYCMainViewModel)
    func updateHaveCardButton(isHidden: Bool)
}

protocol KYCMainViewOutput: AnyObject {
    func didLoad(view: KYCMainViewInput)
    func willDisappear()
    func didTapIssueCardForFree()
    func didTapGetMoreXor()
    func didTapIssueCard()
    func didTapUnsupportedCountriesList()
    func didTapHaveCard()
}

protocol KYCMainInteractorInput: AnyObject {
    var wallet: MetaAccountModel { get }

    func setup(with output: KYCMainInteractorOutput)
    func prepareToDismiss()
}

protocol KYCMainInteractorOutput: AnyObject {
    func didReceive(data: KYCMainData)
    func didReceive(xorChainAssets: [ChainAsset])
    func didReceiveFinalStatus()
}

protocol KYCMainRouterInput: SheetAlertPresentable, WebPresentable, Dismissable {
    func showSwap(from view: ControllerBackedProtocol?, wallet: MetaAccountModel, chainAsset: ChainAsset)
    func showBuyXor(from view: ControllerBackedProtocol?, wallet: MetaAccountModel, chainAsset: ChainAsset)
    func showTermsAndConditions(from view: ControllerBackedProtocol?)
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainModels: [ChainModel]?,
        delegate: SelectNetworkDelegate?
    )
}

protocol KYCMainModuleInput: AnyObject {}

protocol KYCMainModuleOutput: AnyObject {}
