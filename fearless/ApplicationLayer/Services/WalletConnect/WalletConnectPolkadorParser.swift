import Foundation
import BigInt
import SSFUtils
import SSFModels

protocol WalletConnectPolkadorParser {
    func parse(
        transactionPayload: TransactionPayload,
        chain: ChainModel
    ) async throws -> WalletConnectExtrinsic
}

final class WalletConnectPolkadorParserImpl: WalletConnectPolkadorParser {
    private lazy var chainRegistry = {
        ChainRegistryFacade.sharedRegistry
    }()

    private lazy var operationQueue = {
        OperationQueue()
    }()

    func parse(
        transactionPayload: TransactionPayload,
        chain: ChainModel
    ) async throws -> WalletConnectExtrinsic {
        guard
            let blockNumber = BigUInt.fromHexString(transactionPayload.blockNumber),
            let nonce = BigUInt.fromHexString(transactionPayload.nonce),
            let specVersion = BigUInt.fromHexString(transactionPayload.specVersion),
            let tip = BigUInt.fromHexString(transactionPayload.tip),
            let transactionVersion = BigUInt.fromHexString(transactionPayload.transactionVersion)
        else {
            throw ConvenienceError(error: "Can't create requared params from transaction payload")
        }

        let era = try createEra(era: transactionPayload.era)
        let method = try await createCall(chain: chain, transactionPayload: transactionPayload)

        return WalletConnectExtrinsic(
            address: transactionPayload.address,
            blockHash: transactionPayload.blockHash,
            blockNumber: blockNumber,
            era: era,
            genesisHash: transactionPayload.genesisHash,
            method: method,
            nonce: nonce,
            specVersion: UInt32(specVersion),
            tip: tip,
            transactionVersion: UInt32(transactionVersion),
            signedExtensions: transactionPayload.signedExtensions,
            version: transactionPayload.version
        )
    }

    // MARK: - Private methods

    private func createEra(era: String) throws -> Era {
        let data = try Data(hexStringSSF: era)
        let scaleDecoder = try ScaleDecoder(data: data)
        let era = try Era(scaleDecoder: scaleDecoder)
        return era
    }

    private func createCall(
        chain: ChainModel,
        transactionPayload: TransactionPayload
    ) async throws -> WalletConnectPolkadotCall {
        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            throw RuntimeProviderError.providerUnavailable
        }
        let fetchCoderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        operationQueue.addOperation(fetchCoderFactoryOperation)

        return try await withCheckedThrowingContinuation { continuation in
            fetchCoderFactoryOperation.completionBlock = {
                do {
                    let codingFactory = try fetchCoderFactoryOperation.extractNoCancellableResultData()
                    let methodData = try Data(hexStringSSF: transactionPayload.method)
                    let methodDecoder = try codingFactory.createDecoder(from: methodData)

                    let call: WalletConnectPolkadotCall
                    if let callableMethod: RuntimeCall<JSON> = try? methodDecoder.read(of: KnownType.call.rawValue) {
                        call = .callable(value: callableMethod)
                    } else {
                        call = .raw(bytes: methodData)
                    }
                    continuation.resume(returning: call)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
