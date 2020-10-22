import Foundation
import FearlessUtils
import IrohaCrypto
import RobinHood
import BigInt

struct TransferSubscriptionResult {
    let extrinsic: Extrinsic
    let encodedExtrinsic: String
    let call: TransferCall
    let extrinsicHash: Data
    let blockNumber: Int64
    let txIndex: Int16
}

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
        logger.debug("Did start fetching block: \(blockHash.toHex(includePrefix: true))")

        let fetchBlockOperation: JSONRPCOperation<[String], SignedBlock> =
            JSONRPCOperation(engine: engine,
                             method: RPCMethod.getChainBlock,
                             parameters: [blockHash.toHex(includePrefix: true)])

        let parseOperation = createParseOperation(dependingOn: fetchBlockOperation)

        parseOperation.addDependency(fetchBlockOperation)

        parseOperation.completionBlock = {
            do {
                let results = try parseOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                self.logger.debug("Did start handling: \(results)")
                self.handle(results: results)
            } catch {
                self.logger.error("Did receive transfer subscription error: \(error)")
            }
        }

        operationManager.enqueue(operations: [fetchBlockOperation, parseOperation],
                                 in: .sync)
    }

    private func handle(results: [TransferSubscriptionResult]) {
        guard !results.isEmpty else {
            return
        }

        var wrappers: [CompoundOperationWrapper<(TransferSubscriptionResult, Decimal)>] = []

        for result in results {
            let feeOperation: BaseOperation<RuntimeDispatchInfo> =
                JSONRPCOperation(engine: engine,
                                 method: RPCMethod.paymentInfo,
                                 parameters: [result.encodedExtrinsic])

            let mapOperation: BaseOperation<(TransferSubscriptionResult, Decimal)> = ClosureOperation {
                do {
                    let feeString = try feeOperation
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                        .fee

                    let fee = Decimal.fromSubstrateAmount(BigUInt(feeString) ?? BigUInt(0),
                                                          precision: self.addressType.precision) ?? .zero

                    self.logger.debug("Did receive fee: \(result.extrinsicHash) \(fee)")
                    return (result, fee)
                } catch {
                    self.logger.warning("Failed to receive fee: \(result.extrinsicHash) \(error)")
                    return (result, .zero)
                }
            }

            mapOperation.addDependency(feeOperation)

            wrappers.append(CompoundOperationWrapper(targetOperation: mapOperation,
                                                     dependencies: [feeOperation]))
        }

        let saveOperation = storage.saveOperation({
            wrappers.compactMap { wrapper in
                do {
                    let feeResult = try wrapper.targetOperation
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                    return TransactionHistoryItem.createFromSubscriptionResult(feeResult.0,
                                                                               fee: feeResult.1,
                                                                               address: self.address,
                                                                               addressFactory: self.addressFactory)
                } catch {
                    self.logger.error("Failed to save received extrinsic")
                    return nil
                }
            }
        }, { [] })

        let dependencies: [Operation] = wrappers.reduce([]) { (result, wrapper) in
            result + wrapper.allOperations
        }

        dependencies.forEach { saveOperation.addDependency($0) }

        saveOperation.completionBlock = {
            switch saveOperation.result {
            case .success:
                self.logger.debug("Did complete block processing")
                DispatchQueue.main.async {
                    self.eventCenter.notify(with: WalletNewTransactionInserted())
                }
            case .failure(let error):
                self.logger.error("Did fail block processing: \(error)")
            case .none:
                self.logger.error("Block processing cancelled")
            }
        }

        operationManager.enqueue(operations: dependencies + [saveOperation], in: .sync)
    }

    private func createParseOperation(dependingOn fetchOperation: BaseOperation<SignedBlock>)
        -> BaseOperation<[TransferSubscriptionResult]> {

        ClosureOperation {
            let block = try fetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                .block

            let blockNumberData = try Data(hexString: block.header.number)

            let blockNumber = try UInt32(BigUInt(scaleDecoder: ScaleDecoder(data: blockNumberData)))

            return block.extrinsics.enumerated().compactMap { (index, hexExtrinsic) in
                do {
                    let data = try Data(hexString: hexExtrinsic)
                    let extrinsicHash = try data.blake2b32()
                    let extrinsic = try Extrinsic(scaleDecoder: ScaleDecoder(data: data))

                    guard extrinsic.call.moduleIndex == ExtrinsicConstants.balanceModuleIndex else {
                        return nil
                    }

                    let isValidTransfer = [
                        ExtrinsicConstants.transferCallIndex,
                        ExtrinsicConstants.keepAliveTransferIndex
                    ].contains(extrinsic.call.callIndex)

                    guard isValidTransfer, let callData = extrinsic.call.arguments else {
                        return nil
                    }

                    let call = try TransferCall(scaleDecoder: ScaleDecoder(data: callData))

                    return TransferSubscriptionResult(extrinsic: extrinsic,
                                                      encodedExtrinsic: hexExtrinsic,
                                                      call: call,
                                                      extrinsicHash: extrinsicHash,
                                                      blockNumber: Int64(blockNumber),
                                                      txIndex: Int16(index))
                } catch {
                    return nil
                }
            }
        }
    }
}
