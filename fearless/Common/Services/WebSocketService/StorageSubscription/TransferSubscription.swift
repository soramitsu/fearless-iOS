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
    let blockNumber: UInt64
    let txIndex: UInt16
}

private typealias ResultAndFeeOperationWrapper =
    CompoundOperationWrapper<(TransferSubscriptionResult, Decimal)>

final class TransferSubscription {
    let engine: JSONRPCEngine
    let address: String
    let chain: Chain
    let runtimeService: RuntimeCodingServiceProtocol
    let addressFactory: SS58AddressFactoryProtocol
    let txStorage: AnyDataProviderRepository<TransactionHistoryItem>
    let contactOperationFactory: WalletContactOperationFactoryProtocol
    let operationManager: OperationManagerProtocol
    let eventCenter: EventCenterProtocol
    let logger: LoggerProtocol

    init(
        engine: JSONRPCEngine,
        address: String,
        chain: Chain,
        addressFactory: SS58AddressFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        txStorage: AnyDataProviderRepository<TransactionHistoryItem>,
        contactOperationFactory: WalletContactOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol
    ) {
        self.engine = engine
        self.address = address
        self.chain = chain
        self.addressFactory = addressFactory
        self.runtimeService = runtimeService
        self.contactOperationFactory = contactOperationFactory
        self.txStorage = txStorage
        self.operationManager = operationManager
        self.eventCenter = eventCenter
        self.logger = logger
    }

    func process(blockHash: Data) {
        logger.debug("Did start fetching block: \(blockHash.toHex(includePrefix: true))")

        let fetchBlockOperation: JSONRPCOperation<[String], SignedBlock> =
            JSONRPCOperation(
                engine: engine,
                method: RPCMethod.getChainBlock,
                parameters: [blockHash.toHex(includePrefix: true)]
            )

        let parseWrapper = createParseOperation(dependingOn: fetchBlockOperation)

        parseWrapper.allOperations.forEach { $0.addDependency(fetchBlockOperation) }

        parseWrapper.targetOperation.completionBlock = {
            do {
                let results = try parseWrapper.targetOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                self.logger.debug("Did start handling: \(results)")
                self.handle(results: results)
            } catch {
                self.logger.error("Did receive transfer subscription error: \(error)")
            }
        }

        let operations = [fetchBlockOperation] + parseWrapper.allOperations

        operationManager.enqueue(operations: operations, in: .transient)
    }

    private func handle(results: [TransferSubscriptionResult]) {
        guard !results.isEmpty else {
            return
        }

        let feeWrappers = createFeeWrappersFromResults(results)

        let contactWrappers = createContactSaveForResults(results)

        let contactDependencies = contactWrappers.reduce([]) { result, wrapper in
            result + wrapper.allOperations
        }

        let saveOperation = createTxSaveDependingOnFee(wrappers: feeWrappers)

        let txDependencies: [Operation] = feeWrappers.reduce([]) { result, wrapper in
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
            case let .failure(error):
                self.logger.error("Did fail block processing: \(error)")
            case .none:
                self.logger.error("Block processing cancelled")
            }
        }

        let allOperations = contactDependencies + txDependencies + [saveOperation]

        operationManager.enqueue(operations: allOperations, in: .transient)
    }
}

extension TransferSubscription {
    private func createFeeWrappersFromResults(
        _ results: [TransferSubscriptionResult]
    ) -> [ResultAndFeeOperationWrapper] {
        let networkType = SNAddressType(chain: chain)

        return results.map { result in
            let feeOperation: BaseOperation<RuntimeDispatchInfo> =
                JSONRPCOperation(
                    engine: engine,
                    method: RPCMethod.paymentInfo,
                    parameters: [result.encodedExtrinsic]
                )

            let mapOperation: BaseOperation<(TransferSubscriptionResult, Decimal)> = ClosureOperation {
                do {
                    let feeString = try feeOperation
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                        .fee

                    let fee = Decimal.fromSubstrateAmount(
                        BigUInt(feeString) ?? BigUInt(0),
                        precision: networkType.precision
                    ) ?? .zero

                    self.logger.debug("Did receive fee: \(result.extrinsicHash) \(fee)")
                    return (result, fee)
                } catch {
                    self.logger.warning("Failed to receive fee: \(result.extrinsicHash) \(error)")
                    return (result, .zero)
                }
            }

            mapOperation.addDependency(feeOperation)

            return CompoundOperationWrapper(
                targetOperation: mapOperation,
                dependencies: [feeOperation]
            )
        }
    }

    private func createTxSaveDependingOnFee(
        wrappers: [ResultAndFeeOperationWrapper]
    ) -> BaseOperation<Void> {
        txStorage.saveOperation({
            wrappers.compactMap { wrapper in
                do {
                    let feeResult = try wrapper.targetOperation
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                    return TransactionHistoryItem.createFromSubscriptionResult(
                        feeResult.0,
                        fee: feeResult.1,
                        address: self.address,
                        addressFactory: self.addressFactory
                    )
                } catch {
                    self.logger.error("Failed to save received extrinsic")
                    return nil
                }
            }
        }, { [] })
    }

    private func createContactSaveForResults(
        _ results: [TransferSubscriptionResult]
    ) -> [CompoundOperationWrapper<Void>] {
        do {
            let networkType = SNAddressType(chain: chain)
            let accountId = try addressFactory.accountId(
                fromAddress: address,
                type: networkType
            )

            let contacts: Set<Data> = Set(
                results.compactMap { result in
                    guard let origin = try? result.extrinsic.signature?
                        .address.map(to: MultiAddress.self).accountId else {
                        return nil
                    }

                    if origin != accountId {
                        return origin
                    } else {
                        return result.call.dest.accountId
                    }
                }
            )

            return try contacts.map { accountId in
                let address = try addressFactory
                    .address(
                        fromPublicKey: AccountIdWrapper(rawData: accountId),
                        type: networkType
                    )

                return contactOperationFactory.saveByAddressOperation(address)
            }
        } catch {
            return [CompoundOperationWrapper<Void>.createWithError(error)]
        }
    }

    private func createParseOperation(
        dependingOn fetchOperation: BaseOperation<SignedBlock>
    ) -> CompoundOperationWrapper<[TransferSubscriptionResult]> {
        let coderOperation = runtimeService.fetchCoderFactoryOperation()

        let accountId = try? addressFactory.accountId(from: address)

        let decodingOperation = ClosureOperation<[TransferSubscriptionResult]> {
            let block = try fetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                .block

            guard let blockNumberData = BigUInt.fromHexString(block.header.number) else {
                throw BaseOperationError.unexpectedDependentResult
            }

            let blockNumber = UInt32(blockNumberData)

            let coderFactory = try coderOperation.extractNoCancellableResultData()

            return block.extrinsics.enumerated().compactMap { index, hexExtrinsic in
                do {
                    let data = try Data(hexString: hexExtrinsic)
                    let extrinsicHash = try data.blake2b32()

                    let decoder = try coderFactory.createDecoder(from: data)

                    let extrinsic: Extrinsic = try decoder.read(of: GenericType.extrinsic.name)
                    let genericCall = try extrinsic.call.map(to: RuntimeCall<TransferCall>.self)
                    let callPath = CallCodingPath(
                        moduleName: genericCall.moduleName,
                        callName: genericCall.callName
                    )

                    let sender = try extrinsic.signature?.address.map(to: MultiAddress.self).accountId
                    let receiver = genericCall.args.dest.accountId

                    guard callPath.isTransfer, (sender == accountId || receiver == accountId) else {
                        return nil
                    }

                    return TransferSubscriptionResult(
                        extrinsic: extrinsic,
                        encodedExtrinsic: hexExtrinsic,
                        call: genericCall.args,
                        extrinsicHash: extrinsicHash,
                        blockNumber: UInt64(blockNumber),
                        txIndex: UInt16(index)
                    )
                } catch {
                    return nil
                }
            }
        }

        decodingOperation.addDependency(coderOperation)

        return CompoundOperationWrapper(targetOperation: decodingOperation, dependencies: [coderOperation])
    }
}
