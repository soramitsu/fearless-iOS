import UIKit
import RobinHood
import FearlessUtils
import IrohaCrypto

final class SelectValidatorsStartInteractor: RuntimeConstantFetching {
    weak var presenter: SelectValidatorsStartInteractorOutputProtocol?

    private let strategy: SelectValidatorsStartStrategy

    init(strategy: SelectValidatorsStartStrategy) {
        self.strategy = strategy
    }
}

extension SelectValidatorsStartInteractor: SelectValidatorsStartInteractorInputProtocol {
    func setup() {
        strategy.setup()
    }
}
