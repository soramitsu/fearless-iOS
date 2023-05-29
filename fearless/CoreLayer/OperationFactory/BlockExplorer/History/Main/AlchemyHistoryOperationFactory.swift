import Foundation
import RobinHood
import CommonWallet
import IrohaCrypto
import FearlessUtils

final class AlchemyHistoryOperationFactory {
    private let txStorage: AnyDataProviderRepository<TransactionHistoryItem>
    private let alchemyService: AlchemyService

    init(
        txStorage: AnyDataProviderRepository<TransactionHistoryItem>,
        alchemyService: AlchemyService
    ) {
        self.txStorage = txStorage
        self.alchemyService = alchemyService
    }

    private func createReceivedHistoryOperation(address: String) -> BaseOperation<AlchemyHistory> {
        AwaitOperation {
            let receivedRequest = AlchemyHistoryRequest(toAddress: address, category: [.erc20, .external, .internal, .erc1155, .erc721, .specialnft])
            let receivedHistory = try await self.alchemyService.fetchTransactionHistory(request: receivedRequest)

            return receivedHistory.result
        }
    }

    private func createSentHistoryOperation(address: String) -> BaseOperation<AlchemyHistory> {
        AwaitOperation {
            let receivedRequest = AlchemyHistoryRequest(fromAddress: address, category: [.erc20, .external, .internal, .erc1155, .erc721, .specialnft])
            let receivedHistory = try await self.alchemyService.fetchTransactionHistory(request: receivedRequest)

            return receivedHistory.result
        }
    }

    private func createMapOperation(
        dependingOn receivedOperation: BaseOperation<AlchemyHistory>,
        sentOperation: BaseOperation<AlchemyHistory>,
        address: String,
        asset: AssetModel,
        chain: ChainModel
    ) -> BaseOperation<AssetTransactionPageData?> {
        ClosureOperation {
            let received = try receivedOperation.extractNoCancellableResultData()
            let sent = try sentOperation.extractNoCancellableResultData()

            let history = received.transfers + sent.transfers

            let transactions = history
                .filter { $0.asset.lowercased() == asset.symbol.lowercased() }
                .sorted(by: { $0.timestampInSeconds > $1.timestampInSeconds })
                .compactMap {
                    AssetTransactionData.createTransaction(from: $0, address: address, chain: chain, asset: asset)
                }

            return AssetTransactionPageData(transactions: transactions)
        }
    }
}

extension AlchemyHistoryOperationFactory: HistoryOperationFactoryProtocol {
    func fetchTransactionHistoryOperation(
        asset: AssetModel,
        chain: ChainModel,
        address: String,
        filters _: [WalletTransactionHistoryFilter],
        pagination _: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        let receivedOperation = createReceivedHistoryOperation(address: address)
        let sentOperation = createSentHistoryOperation(address: address)

        let mapOperation = createMapOperation(
            dependingOn: receivedOperation,
            sentOperation: sentOperation,
            address: address,
            asset: asset,
            chain: chain
        )

        mapOperation.addDependency(receivedOperation)
        mapOperation.addDependency(sentOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [receivedOperation, sentOperation])
    }
}
