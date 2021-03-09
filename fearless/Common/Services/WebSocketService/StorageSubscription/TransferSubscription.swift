import Foundation
import FearlessUtils
import IrohaCrypto
import RobinHood
import BigInt

enum ExtrinsicResult {
    case v28(_ extrinsic: Extrinsic)
    case v27(_ extrinsic: ExtrinsicV27)

    var call: Call {
        switch self {
        case .v28(let extrinsic):
            return extrinsic.call
        case .v27(let extrinsic):
            return extrinsic.call
        }
    }

    var sender: Data? {
        switch self {
        case .v28(let extrinsic):
            if case .accountId(let value) = extrinsic.transaction?.address {
                return value
            } else {
                return nil
            }
        case .v27(let extrinsic):
            return extrinsic.transaction?.accountId
        }
    }
}

enum TransferCallResult {
    case v28(_ call: TransferCall)
    case v27(_ call: TransferCallV27)

    var receiver: Data? {
        switch self {
        case .v28(let call):
            if case .accountId(let value) = call.receiver {
                return value
            } else {
                return nil
            }
        case .v27(let call):
            return call.receiver
        }
    }

    var amount: BigUInt {
        switch self {
        case .v28(let call):
            return call.amount
        case .v27(let call):
            return call.amount
        }
    }
}

struct TransferSubscriptionResult {
    let extrinsic: ExtrinsicResult
    let encodedExtrinsic: String
    let call: TransferCallResult
    let extrinsicHash: Data
    let blockNumber: Int64
    let txIndex: Int16
}

private typealias ResultAndFeeOperationWrapper =
    CompoundOperationWrapper<(TransferSubscriptionResult, Decimal)>

final class TransferSubscription {
    let engine: JSONRPCEngine
    let address: String
    let chain: Chain
    let addressFactory: SS58AddressFactoryProtocol
    let txStorage: AnyDataProviderRepository<TransactionHistoryItem>
    let chainStorage: AnyDataProviderRepository<ChainStorageItem>
    let localIdFactory: ChainStorageIdFactoryProtocol
    let contactOperationFactory: WalletContactOperationFactoryProtocol
    let operationManager: OperationManagerProtocol
    let eventCenter: EventCenterProtocol
    let logger: LoggerProtocol

    init(engine: JSONRPCEngine,
         address: String,
         chain: Chain,
         addressFactory: SS58AddressFactoryProtocol,
         txStorage: AnyDataProviderRepository<TransactionHistoryItem>,
         chainStorage: AnyDataProviderRepository<ChainStorageItem>,
         localIdFactory: ChainStorageIdFactoryProtocol,
         contactOperationFactory: WalletContactOperationFactoryProtocol,
         operationManager: OperationManagerProtocol,
         eventCenter: EventCenterProtocol,
         logger: LoggerProtocol) {
        self.engine = engine
        self.address = address
        self.chain = chain
        self.addressFactory = addressFactory
        self.contactOperationFactory = contactOperationFactory
        self.txStorage = txStorage
        self.chainStorage = chainStorage
        self.localIdFactory = localIdFactory
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

        let upgradedOperation = createUpgradedOperation()

        let parseOperation = createParseOperation(dependingOn: fetchBlockOperation,
                                                  upgradedOperation: upgradedOperation)

        parseOperation.addDependency(fetchBlockOperation)
        upgradedOperation.allOperations.forEach { parseOperation.addDependency($0) }

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

        let operations = upgradedOperation.allOperations + [fetchBlockOperation, parseOperation]

        operationManager.enqueue(operations: operations,
                                 in: .transient)
    }

    private func createUpgradedOperation() -> CompoundOperationWrapper<Bool?> {
        do {
            let remoteKey = try StorageKeyFactory().updatedDualRefCount()
            let localKey = localIdFactory.createIdentifier(for: remoteKey)

            return chainStorage.queryStorageByKey(localKey)
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    private func handle(results: [TransferSubscriptionResult]) {
        guard !results.isEmpty else {
            return
        }

        let feeWrappers = createFeeWrappersFromResults(results)

        let contactWrappers = createContactSaveForResults(results)

        let contactDependencies = contactWrappers.reduce([]) { (result, wrapper) in
            result + wrapper.allOperations
        }

        let saveOperation = createTxSaveDependingOnFee(wrappers: feeWrappers)

        let txDependencies: [Operation] = feeWrappers.reduce([]) { (result, wrapper) in
            result + wrapper.allOperations
        }

        txDependencies.forEach { saveOperation.addDependency($0) }

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

        let allOperations = contactDependencies + txDependencies + [saveOperation]

        operationManager.enqueue(operations: allOperations, in: .sync)
    }
}

extension TransferSubscription {
    private func createFeeWrappersFromResults(_ results: [TransferSubscriptionResult])
        -> [ResultAndFeeOperationWrapper] {

        let networkType = SNAddressType(chain: chain)

        return results.map { result in
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
                                                          precision: networkType.precision) ?? .zero

                    self.logger.debug("Did receive fee: \(result.extrinsicHash) \(fee)")
                    return (result, fee)
                } catch {
                    self.logger.warning("Failed to receive fee: \(result.extrinsicHash) \(error)")
                    return (result, .zero)
                }
            }

            mapOperation.addDependency(feeOperation)

            return CompoundOperationWrapper(targetOperation: mapOperation,
                                            dependencies: [feeOperation])
        }
    }

    private func createTxSaveDependingOnFee(wrappers: [ResultAndFeeOperationWrapper])
        -> BaseOperation<Void> {
        txStorage.saveOperation({
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
    }

    private func createContactSaveForResults(_ results: [TransferSubscriptionResult])
        -> [CompoundOperationWrapper<Void>] {
        do {
            let networkType = SNAddressType(chain: chain)
            let accountId = try addressFactory.accountId(fromAddress: address,
                                                         type: networkType)

            let contacts: Set<Data> = Set(
                results.compactMap { result in
                    guard let origin = result.extrinsic.sender else {
                        return nil
                    }

                    if origin != accountId {
                        return origin
                    } else {
                        return result.call.receiver
                    }
                }
            )

            return try contacts.map { accountId in
                let address = try addressFactory
                    .address(fromPublicKey: AccountIdWrapper(rawData: accountId),
                             type: networkType)

                return contactOperationFactory.saveByAddressOperation(address)
            }
        } catch {
            return [CompoundOperationWrapper<Void>.createWithError(error)]
        }
    }

    private func createParseOperation(dependingOn fetchOperation: BaseOperation<SignedBlock>,
                                      upgradedOperation: CompoundOperationWrapper<Bool?>)
        -> BaseOperation<[TransferSubscriptionResult]> {

        let currentChain = chain

        return ClosureOperation {
            let block = try fetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                .block

            let upgraded = (try upgradedOperation.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)) ?? false

            let blockNumberData = try Data(hexString: block.header.number)

            let blockNumber = UInt32(BigUInt(blockNumberData))

            return block.extrinsics.enumerated().compactMap { (index, hexExtrinsic) in
                do {
                    let data = try Data(hexString: hexExtrinsic)
                    let extrinsicHash = try data.blake2b32()
                    let extrinsicResult: ExtrinsicResult

                    if upgraded {
                        let extrinsic = try Extrinsic(scaleDecoder: ScaleDecoder(data: data))
                        extrinsicResult = .v28(extrinsic)
                    } else {
                        let extrinsicV27 = try ExtrinsicV27(scaleDecoder: ScaleDecoder(data: data))
                        extrinsicResult = .v27(extrinsicV27)
                    }

                    guard extrinsicResult.call.moduleIndex == currentChain.balanceModuleIndex else {
                        return nil
                    }

                    let isValidTransfer = [
                        currentChain.transferCallIndex,
                        currentChain.keepAliveTransferCallIndex
                    ].contains(extrinsicResult.call.callIndex)

                    guard isValidTransfer, let callData = extrinsicResult.call.arguments else {
                        return nil
                    }

                    let callResult: TransferCallResult

                    if upgraded {
                        let call = try TransferCall(scaleDecoder: ScaleDecoder(data: callData))
                        callResult = .v28(call)
                    } else {
                        let call = try TransferCallV27(scaleDecoder: ScaleDecoder(data: callData))
                        callResult = .v27(call)
                    }

                    return TransferSubscriptionResult(extrinsic: extrinsicResult,
                                                      encodedExtrinsic: hexExtrinsic,
                                                      call: callResult,
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
