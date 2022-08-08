typealias WalletOptionModuleCreationResult = (view: WalletOptionViewInput, input: WalletOptionModuleInput)

protocol WalletOptionViewInput: ControllerBackedProtocol {}

protocol WalletOptionViewOutput: AnyObject {
    func didLoad(view: WalletOptionViewInput)
}

protocol WalletOptionInteractorInput: AnyObject {
    func setup(with output: WalletOptionInteractorOutput)
}

protocol WalletOptionInteractorOutput: AnyObject {}

protocol WalletOptionRouterInput: AnyObject {}

protocol WalletOptionModuleInput: AnyObject {}

protocol WalletOptionModuleOutput: AnyObject {}
