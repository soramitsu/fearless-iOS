import Foundation

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
            let target = operationWrapper.targetOperation
            queue.async {
                // Do not emit completion if cancelled during teardown
                guard !target.isCancelled else { return }
                completionBlock(target.result)
            }
        }

        operationQueue.addOperations(
            operationWrapper.allOperations,
            waitUntilFinished: false
        )

        return operationWrapper
    }
}
