typealias BalanceLocksDetailModuleCreationResult = (view: BalanceLocksDetailViewInput, input: BalanceLocksDetailModuleInput)

protocol BalanceLocksDetailViewInput: ControllerBackedProtocol {}

protocol BalanceLocksDetailViewOutput: AnyObject {
    func didLoad(view: BalanceLocksDetailViewInput)
}

protocol BalanceLocksDetailInteractorInput: AnyObject {
    func setup(with output: BalanceLocksDetailInteractorOutput)
}

protocol BalanceLocksDetailInteractorOutput: AnyObject {}

protocol BalanceLocksDetailRouterInput: AnyObject {}

protocol BalanceLocksDetailModuleInput: AnyObject {}

protocol BalanceLocksDetailModuleOutput: AnyObject {}
