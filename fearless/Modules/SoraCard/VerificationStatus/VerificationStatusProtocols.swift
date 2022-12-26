typealias VerificationStatusModuleCreationResult = (view: VerificationStatusViewInput, input: VerificationStatusModuleInput)

protocol VerificationStatusViewInput: ControllerBackedProtocol {
    func didReceive(status: SoraCardStatus)
}

protocol VerificationStatusViewOutput: AnyObject {
    func didLoad(view: VerificationStatusViewInput)
    func didTapCloseButton()
    func didTapTryagainButton()
}

protocol VerificationStatusInteractorInput: AnyObject {
    func setup(with output: VerificationStatusInteractorOutput)
    func getKYCStatus()
}

protocol VerificationStatusInteractorOutput: AnyObject {
    func didReceive(error: Error)
    func didReceive(status: SCVerificationStatus)
}

protocol VerificationStatusRouterInput: AnyObject {}

protocol VerificationStatusModuleInput: AnyObject {}

protocol VerificationStatusModuleOutput: AnyObject {}
