import UIKit

final class BalanceLocksDetailInteractor {
    // MARK: - Private properties

    private weak var output: BalanceLocksDetailInteractorOutput?
    private let storageRequestPerformer: StorageRequestPerformer
    
    init(storageRequestPerformer: StorageRequestPerformer) {
        self.storageRequestPerformer = storageRequestPerformer
        
    }
}

// MARK: - BalanceLocksDetailInteractorInput

extension BalanceLocksDetailInteractor: BalanceLocksDetailInteractorInput {
    func setup(with output: BalanceLocksDetailInteractorOutput) {
        self.output = output
    }
}
