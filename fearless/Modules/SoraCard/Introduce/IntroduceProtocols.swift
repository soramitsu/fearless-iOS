typealias IntroduceModuleCreationResult = (view: IntroduceViewInput, input: IntroduceModuleInput)

protocol IntroduceViewInput: ControllerBackedProtocol {}

protocol IntroduceViewOutput: AnyObject {
    func didLoad(view: IntroduceViewInput)
}

protocol IntroduceInteractorInput: AnyObject {
    func setup(with output: IntroduceInteractorOutput)
}

protocol IntroduceInteractorOutput: AnyObject {}

protocol IntroduceRouterInput: AnyObject {}

protocol IntroduceModuleInput: AnyObject {}

protocol IntroduceModuleOutput: AnyObject {}
