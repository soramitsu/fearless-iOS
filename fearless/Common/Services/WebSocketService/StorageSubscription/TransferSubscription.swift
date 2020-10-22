import Foundation
import FearlessUtils
import IrohaCrypto
import RobinHood
import BigInt

final class TransferSubscription {
    let engine: JSONRPCEngine
    let address: String
    let addressType: SNAddressType
    let addressFactory: SS58AddressFactoryProtocol
    let storage: AnyDataProviderRepository<TransactionHistoryItem>
    let operationManager: OperationManagerProtocol
    let eventCenter: EventCenterProtocol
    let logger: LoggerProtocol

    init(engine: JSONRPCEngine,
         address: String,
         addressType: SNAddressType,
         addressFactory: SS58AddressFactoryProtocol,
         storage: AnyDataProviderRepository<TransactionHistoryItem>,
         operationManager: OperationManagerProtocol,
         eventCenter: EventCenterProtocol,
         logger: LoggerProtocol) {
        self.engine = engine
        self.address = address
        self.addressType = addressType
        self.addressFactory = addressFactory
        self.storage = storage
        self.operationManager = operationManager
        self.eventCenter = eventCenter
        self.logger = logger
    }

    func process(blockHash: Data) {
        let fetchBlockOperation: JSONRPCOperation<[String], Block> =
            JSONRPCOperation(engine: engine,
                             method: RPCMethod.getChainBlock,
                             parameters: [blockHash.toHex(includePrefix: true)])

        let parseOperation = createParseOperation(dependingOn: fetchBlockOperation)

        parseOperation.addDependency(fetchBlockOperation)

        let saveOperation = storage.saveOperation({
            try parseOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        }, { [] })

        saveOperation.addDependency(parseOperation)

        saveOperation.completionBlock = {
            DispatchQueue.main.async {
                self.eventCenter.notify(with: WalletNewTransactionInserted())
            }
        }

        operationManager.enqueue(operations: [fetchBlockOperation, parseOperation, saveOperation],
                                 in: .sync)
    }

    private func createParseOperation(dependingOn fetchOperation: BaseOperation<Block>)
        -> BaseOperation<[TransactionHistoryItem]> {
        ClosureOperation {
            let block = try fetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            let blockNumberData = try Data(hexString: block.header.number)

            let blockNumber = try UInt32(BigUInt(scaleDecoder: ScaleDecoder(data: blockNumberData)))

            return block.extrinsics.enumerated().compactMap { (index, hexExtrinsic) in
                do {
                    let data = try Data(hexString: hexExtrinsic)
                    let extrinsicHash = try data.blake2b32()
                    let extrinsic = try Extrinsic(scaleDecoder: ScaleDecoder(data: data))
                    return TransactionHistoryItem.createFromExtrinsic(extrinsic,
                                                                      fee: .zero,
                                                                      address: self.address,
                                                                      txHash: extrinsicHash,
                                                                      blockNumber: blockNumber,
                                                                      txIndex: Int16(index),
                                                                      addressFactory: self.addressFactory)
                } catch {
                    return nil
                }
            }
        }
    }
}
