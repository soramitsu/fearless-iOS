import Foundation

protocol TransactionObserver {
    func subscribe(transactionHash: String) async throws -> AsyncThrowingStream<ExtrinsicStatus, Error>
}
