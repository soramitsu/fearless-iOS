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
    func didTapStartKyc()
    func didTapHide()
}

protocol SoraCardInfoBoardInteractorInput: AnyObject {
    func setup(with output: SoraCardInfoBoardInteractorOutput)
    func getKYCStatus()
    func hideCard()
}

protocol SoraCardInfoBoardInteractorOutput: AnyObject {
    func didReceive(error: Error)
    func didReceive(status: SCKYCStatusResponse?)
    func didReceive(hiddenState: Bool)
}

protocol SoraCardInfoBoardRouterInput: AnyObject, SheetAlertPresentable {
    func presentTermsAndConditions(from view: SoraCardInfoBoardViewInput?)
    func presentPreparation(from view: ControllerBackedProtocol?)
}

protocol SoraCardInfoBoardModuleInput: AnyObject {
    func add(moduleOutput: SoraCardInfoBoardModuleOutput?)
}

protocol SoraCardInfoBoardModuleOutput: AnyObject {
    func didChanged(soraCardHiddenState: Bool)
}
