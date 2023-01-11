import SoraFoundation

typealias SoraCardInfoBoardModuleCreationResult = (view: SoraCardInfoBoardViewInput, input: SoraCardInfoBoardModuleInput)

protocol SoraCardInfoBoardViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(stateViewModel: LocalizableResource<SoraCardInfoViewModel>)
}

protocol SoraCardInfoBoardViewOutput: AnyObject {
    func didLoad(view: SoraCardInfoBoardViewInput)
    func didTapGetSoraCard()
    func didTapKYCStatus()
    func didTapBalance()
    func didTapRefresh()
}

protocol SoraCardInfoBoardInteractorInput: AnyObject {
    func setup(with output: SoraCardInfoBoardInteractorOutput)
    func getKYCStatus()
}

protocol SoraCardInfoBoardInteractorOutput: AnyObject {
    func didReceive(error: Error)
    func didReceive(status: SCKYCStatusResponse)
}

protocol SoraCardInfoBoardRouterInput: AnyObject {
    func presentTermsAndConditions(from view: SoraCardInfoBoardViewInput?)
}

protocol SoraCardInfoBoardModuleInput: AnyObject {}

protocol SoraCardInfoBoardModuleOutput: AnyObject {}
