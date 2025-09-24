import UIKit

final class LiquidityPoolsOverviewInteractor {
    // MARK: - Private properties

    private weak var output: LiquidityPoolsOverviewInteractorOutput?
    private let transactionObserver: TransactionObserver

    init(transactionObserver: TransactionObserver) {
        self.transactionObserver = transactionObserver
    }
}

// MARK: - LiquidityPoolsOverviewInteractorInput

extension LiquidityPoolsOverviewInteractor: LiquidityPoolsOverviewInteractorInput {
    func setup(with output: LiquidityPoolsOverviewInteractorOutput) {
        self.output = output
    }

    func subscribe(transactionHash: String) {
        Task {
            let transactionObserverStream = try await self.transactionObserver.subscribe(transactionHash: transactionHash)

            for try await transactionStatus in transactionObserverStream {
                switch transactionStatus {
                case .finalized:
                    output?.didReceiveTransactionFinalizedEvent()
                default: break
                }
            }
        }
    }
}
