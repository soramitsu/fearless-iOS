import UIKit

protocol AccountStatisticsInteractorOutput: AnyObject {}

final class AccountStatisticsInteractor {
    // MARK: - Private properties

    private weak var output: AccountStatisticsInteractorOutput?
}

// MARK: - AccountStatisticsInteractorInput

extension AccountStatisticsInteractor: AccountStatisticsInteractorInput {
    func setup(with output: AccountStatisticsInteractorOutput) {
        self.output = output
    }
}
