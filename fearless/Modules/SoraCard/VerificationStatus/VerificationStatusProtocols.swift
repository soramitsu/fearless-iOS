typealias VerificationStatusModuleCreationResult = (view: VerificationStatusViewInput, input: VerificationStatusModuleInput)

protocol VerificationStatusViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(status: SoraCardStatus)
    func didReceive(error: Error?)
}

protocol VerificationStatusViewOutput: AnyObject {
    func didLoad(view: VerificationStatusViewInput)
    func didTapActionButton()
    func didTapSupportButton()
    func didTapRefresh()
}

protocol VerificationStatusInteractorInput: AnyObject {
    func setup(with output: VerificationStatusInteractorOutput)
    func getKYCStatus()
    func retryKYC() async
    func resetKYC() async
    func restartKYC()
}

protocol VerificationStatusInteractorOutput: AnyObject {
    func didReceive(error: Error)
    func didReceive(status: SCKYCUserStatus?, hasFreeAttempts: Bool)
    func resetKYC()
}

protocol VerificationStatusRouterInput: PresentDismissable, WebPresentable {}

protocol VerificationStatusModuleInput: AnyObject {}

protocol VerificationStatusModuleOutput: AnyObject {}
