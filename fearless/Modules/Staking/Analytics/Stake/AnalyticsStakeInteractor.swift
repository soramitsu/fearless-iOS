import RobinHood
import BigInt

final class AnalyticsStakeInteractor {
    weak var presenter: AnalyticsStakeInteractorOutputProtocol!

    let subqueryStakeSource: SubqueryStakeSource
    let operationManager: OperationManagerProtocol

    init(
        subqueryStakeSource: SubqueryStakeSource,
        operationManager: OperationManagerProtocol
    ) {
        self.subqueryStakeSource = subqueryStakeSource
        self.operationManager = operationManager
    }

    private func fetchStakeData() {
        let fetchOperation = subqueryStakeSource.fetchOperation()
        fetchOperation.targetOperation.completionBlock = { [weak presenter] in
            DispatchQueue.main.async {
                do {
                    let response = try fetchOperation.targetOperation.extractNoCancellableResultData() ?? []
                    presenter?.didReceieve(stakeDataResult: .success(response))
                } catch {
                    presenter?.didReceieve(stakeDataResult: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: fetchOperation.allOperations, in: .transient)
    }
}

extension AnalyticsStakeInteractor: AnalyticsStakeInteractorInputProtocol {
    func setup() {
        // fetchStakeData()
        let timestamp = Int64(Date().timeIntervalSince1970)
        let data = (0 ... 100).map { index in
            SubqueryStakeChangeData(
                timestamp: timestamp - Int64(index) * 10000,
                address: "",
                amount: BigUInt(integerLiteral: UInt64(index * 10_000_000)),
                type: .bonded
            )
        }
        presenter.didReceieve(stakeDataResult: .success(data))
    }
}
