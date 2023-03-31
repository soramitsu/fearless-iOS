typealias KYCMainModuleCreationResult = (view: KYCMainViewInput, input: KYCMainModuleInput)

protocol KYCMainViewInput: ControllerBackedProtocol {
    func set(viewModel: KYCMainViewModel)
    func updateHaveCardButton(isHidden: Bool)
    func show(environment: String)
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
    var xorChainAssets: [ChainAsset] { get }

    func setup(with output: KYCMainInteractorOutput)
    func prepareToDismiss()
}

protocol KYCMainInteractorOutput: AnyObject {
    func didReceive(data: KYCMainData)
}

protocol KYCMainRouterInput: SheetAlertPresentable, WebPresentable, ModalAlertPresenting {
    func showSwap(from view: ControllerBackedProtocol?, wallet: MetaAccountModel, chainAsset: ChainAsset)
    func showBuyXor(from view: ControllerBackedProtocol?, wallet: MetaAccountModel, chainAsset: ChainAsset)
    func showTermsAndConditions(from view: ControllerBackedProtocol?)
}

protocol KYCMainModuleInput: AnyObject {}

protocol KYCMainModuleOutput: AnyObject {}
