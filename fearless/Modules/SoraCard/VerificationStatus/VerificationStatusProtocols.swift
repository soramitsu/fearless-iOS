typealias VerificationStatusModuleCreationResult = (view: VerificationStatusViewInput, input: VerificationStatusModuleInput)

protocol VerificationStatusViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(status: SoraCardStatus)
    func didReceive(error: Error?)
}

protocol VerificationStatusViewOutput: AnyObject {
    func didLoad(view: VerificationStatusViewInput)
    func didTapCloseButton()
    func didTapTryAgainButton()
    func didTapRefresh()
}

protocol VerificationStatusInteractorInput: AnyObject {
    func setup(with output: VerificationStatusInteractorOutput)
    func getKYCStatus()
}

protocol VerificationStatusInteractorOutput: AnyObject {
    func didReceive(error: Error)
    func didReceive(status: SCVerificationStatus)
}

protocol VerificationStatusRouterInput: PresentDismissable {}

protocol VerificationStatusModuleInput: AnyObject {}

protocol VerificationStatusModuleOutput: AnyObject {}
