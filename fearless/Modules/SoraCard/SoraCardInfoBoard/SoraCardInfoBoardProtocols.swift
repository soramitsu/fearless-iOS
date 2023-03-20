import SoraFoundation

typealias SoraCardInfoBoardModuleCreationResult = (view: SoraCardInfoBoardViewInput, input: SoraCardInfoBoardModuleInput)

protocol SoraCardInfoBoardViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(stateViewModel: SoraCardInfoViewModel)
}

protocol SoraCardInfoBoardViewOutput: AnyObject {
    func didLoad(view: SoraCardInfoBoardViewInput)
    func didTapGetSoraCard()
    func didTapHide()
}

protocol SoraCardInfoBoardInteractorInput: AnyObject {
    func setup(with output: SoraCardInfoBoardInteractorOutput)
    func hideCard()
    func fetchStatus() async -> SCKYCUserStatus?
}

protocol SoraCardInfoBoardInteractorOutput: AnyObject {
    func didReceive(status: SCKYCUserStatus)
    func didReceive(hiddenState: Bool)
}

protocol SoraCardInfoBoardRouterInput: AnyObject, SheetAlertPresentable {
    func startKYC(from view: SoraCardInfoBoardViewInput?, data: SCKYCUserDataModel, wallet: MetaAccountModel)
    func presentPreparation(from view: ControllerBackedProtocol?)
}

protocol SoraCardInfoBoardModuleInput: AnyObject {
    func add(moduleOutput: SoraCardInfoBoardModuleOutput?)
}

protocol SoraCardInfoBoardModuleOutput: AnyObject {
    func didChanged(soraCardHiddenState: Bool)
}
