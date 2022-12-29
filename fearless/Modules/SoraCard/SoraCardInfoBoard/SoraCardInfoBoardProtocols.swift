typealias SoraCardInfoBoardModuleCreationResult = (view: SoraCardInfoBoardViewInput, input: SoraCardInfoBoardModuleInput)

protocol SoraCardInfoBoardViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(stateViewModel: SoraCardState)
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

protocol SoraCardInfoBoardRouterInput: AnyObject {}

protocol SoraCardInfoBoardModuleInput: AnyObject {}

protocol SoraCardInfoBoardModuleOutput: AnyObject {}
