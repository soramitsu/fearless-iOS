import Foundation
import RobinHood

extension SubqueryHistoryOperationFactory: WalletRemoteHistoryFactoryProtocol {
    func createOperationWrapper(
        for context: TransactionHistoryContext,
        address: String,
        count: Int
    ) -> CompoundOperationWrapper<WalletRemoteHistoryData> {
        let queryOperation = createOperation(address: address, count: count, cursor: context.cursor)

        let mappingOperation = ClosureOperation<WalletRemoteHistoryData> {
            let response = try queryOperation.extractNoCancellableResultData()

            let pageInfo = response.historyElements.pageInfo
            let items = response.historyElements.nodes

            let context = TransactionHistoryContext(
                cursor: pageInfo.endCursor,
                isComplete: pageInfo.endCursor == nil
            )

            return WalletRemoteHistoryData(
                historyItems: items,
                context: context
            )
        }

        mappingOperation.addDependency(queryOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [queryOperation])
    }
}
