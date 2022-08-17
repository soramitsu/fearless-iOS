import Foundation
import RobinHood

final class ValidatorSearchInteractor {
    weak var presenter: ValidatorSearchInteractorOutputProtocol!

    let strategy: ValidatorSearchStrategy

    private var currentOperation: CompoundOperationWrapper<[SelectedValidatorInfo]>?

    init(strategy: ValidatorSearchStrategy) {
        self.strategy = strategy
    }
}

extension ValidatorSearchInteractor: ValidatorSearchInteractorInputProtocol {
    func performValidatorSearch(accountId: AccountId) {
        strategy.performValidatorSearch(accountId: accountId)
    }
}
