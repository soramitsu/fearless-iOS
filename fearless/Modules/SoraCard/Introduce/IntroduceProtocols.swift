typealias IntroduceModuleCreationResult = (view: IntroduceViewInput, input: IntroduceModuleInput)

protocol IntroduceViewInput: ControllerBackedProtocol {}

protocol IntroduceViewOutput: AnyObject {
    func didLoad(view: IntroduceViewInput)
    func didTapContinueButton(name: String, lastName: String)
    func didTapBackButton()
    func didTapCloseButton()
}

protocol IntroduceInteractorInput: AnyObject {
    func setup(with output: IntroduceInteractorOutput)
}

protocol IntroduceInteractorOutput: AnyObject {}

protocol IntroduceRouterInput: PushDismissable {
    func presentVerificationEmail(
        from view: IntroduceViewInput?,
        phone: String,
        name: String,
        lastName: String
    )
    func close(from view: IntroduceViewInput?)
}

protocol IntroduceModuleInput: AnyObject {}

protocol IntroduceModuleOutput: AnyObject {}
