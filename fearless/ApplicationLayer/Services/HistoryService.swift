import Foundation
import CommonWallet
import RobinHood
import SSFModels

typealias TransactionHistoryBlock = (Result<AssetTransactionPageData?, Error>?) -> Void

protocol HistoryServiceProtocol {
    @discardableResult
    func fetchTransactionHistory(
        for address: String,
        asset: AssetModel,
        chain: ChainModel,
        filters: [WalletTransactionHistoryFilter],
        pagination: Pagination,
        runCompletionIn queue: DispatchQueue,
        completionBlock: @escaping TransactionHistoryBlock
    ) -> CancellableCall
}

class HistoryService: HistoryServiceProtocol {
    let operationFactory: HistoryOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(operationFactory: HistoryOperationFactoryProtocol, operationQueue: OperationQueue) {
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
    }

    @discardableResult
    func fetchTransactionHistory(
        for address: String,
        asset: AssetModel,
        chain: ChainModel,
        filters: [WalletTransactionHistoryFilter],
        pagination: Pagination,
        runCompletionIn queue: DispatchQueue,
        completionBlock: @escaping TransactionHistoryBlock
    ) -> CancellableCall {
        let operationWrapper = operationFactory.fetchTransactionHistoryOperation(
            asset: asset,
            chain: chain,
            address: address,
            filters: filters,
            pagination: pagination
        )

        operationWrapper.targetOperation.completionBlock = {
            queue.async {
                completionBlock(operationWrapper.targetOperation.result)
            }
        }

        operationQueue.addOperations(
            operationWrapper.allOperations,
            waitUntilFinished: false
        )

        return operationWrapper
    }
}
