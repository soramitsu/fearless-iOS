import RobinHood
import SSFModels

class ValidatorInfoInteractorBase: ValidatorInfoInteractorInputProtocol {
    weak var presenter: ValidatorInfoInteractorOutputProtocol!

    private let chainAsset: ChainAsset
    private let strategy: ValidatorInfoStrategy

    init(
        chainAsset: ChainAsset,
        strategy: ValidatorInfoStrategy
    ) {
        self.chainAsset = chainAsset
        self.strategy = strategy
    }

    func setup() {
        strategy.setup()
    }

    func reload() {
        strategy.reload()
    }
}
