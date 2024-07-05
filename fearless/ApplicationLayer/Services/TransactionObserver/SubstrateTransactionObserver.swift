import Foundation
import SSFChainConnection
import SSFUtils

final class SubstrateTransactionObserver: TransactionObserver {
    private let engine: SubstrateConnection
    private var activeRequestIds: [UInt16] = []

    init(engine: SubstrateConnection) {
        self.engine = engine
    }

    deinit {
        activeRequestIds.forEach { try? engine.unsubsribe($0) }
    }

    func subscribe(transactionHash: String) async throws -> AsyncThrowingStream<ExtrinsicStatus, Error> {
        AsyncThrowingStream<ExtrinsicStatus, Error> { continuation in
            let updateClosure: (JSONRPCSubscriptionUpdate<ExtrinsicStatus>) -> Void = { statusUpdate in
                let state = statusUpdate.params.result
                continuation.yield(state)
            }

            let failureClosure: (Error, Bool) -> Void = { error, _ in
                continuation.finish(throwing: error)
            }

            let requestId = engine.generateRequestId()
            activeRequestIds.append(requestId)
            let subscription = JSONRPCSubscription(
                requestId: requestId,
                requestData: .init(),
                requestOptions: .init(resendOnReconnect: true),
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )

            subscription.remoteId = transactionHash
            engine.addSubscription(subscription)
        }
    }

    private func cancelSubscription(requestId: UInt16) {
        engine.cancelForIdentifier(requestId)
    }
}
