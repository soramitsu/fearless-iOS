import SoraFoundation

typealias SoraCardInfoBoardModuleCreationResult = (view: SoraCardInfoBoardViewInput, input: SoraCardInfoBoardModuleInput)

protocol SoraCardInfoBoardViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(status: SoraCardStatus)
}

protocol SoraCardInfoBoardViewOutput: AnyObject {
    func didLoad(view: SoraCardInfoBoardViewInput)
    func didTapStart()
    func didTapHide()
}

protocol SoraCardInfoBoardInteractorInput: AnyObject {
    func setup(with output: SoraCardInfoBoardInteractorOutput)
    func hideCard()
    func fetchStatus() async
    func prepareStart() async
}

protocol SoraCardInfoBoardInteractorOutput: AnyObject {
    func didReceive(status: SCKYCUserStatus?, hasFreeAttempts: Bool)
    func didReceive(hiddenState: Bool)
    func didReceive(kycStatuses: [SCKYCStatusResponse])
    func didReceive(error: NetworkingError)
    func restartKYC(data: SCKYCUserDataModel?)
}

protocol SoraCardInfoBoardRouterInput: SheetAlertPresentable, ErrorPresentable {
    func start(from view: SoraCardInfoBoardViewInput?, data: SCKYCUserDataModel, wallet: MetaAccountModel)
    func showVerificationStatus(from view: SoraCardInfoBoardViewInput?)
}

protocol SoraCardInfoBoardModuleInput: AnyObject {
    func add(moduleOutput: SoraCardInfoBoardModuleOutput?)
}

protocol SoraCardInfoBoardModuleOutput: AnyObject {
    func didChanged(soraCardHiddenState: Bool)
}
