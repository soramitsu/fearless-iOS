import Foundation
import BigInt
import SSFUtils
import SSFModels

protocol WalletConnectPolkadotParser {
    func parse(
        transactionPayload: TransactionPayload,
        chain: ChainModel
    ) async throws -> WalletConnectExtrinsic
}

final class WalletConnectPolkadorParserImpl: WalletConnectPolkadotParser {
    private lazy var chainRegistry = {
        ChainRegistryFacade.sharedRegistry
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
            throw ConvenienceError(error: "Can't create required params from transaction payload")
        }

        let era = try decodeEraFrom(scale: transactionPayload.era)
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

    private func decodeEraFrom(scale: String) throws -> Era {
        let data = try Data(hexStringSSF: scale)
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
        let codingFactory = try await runtimeProvider.fetchCoderFactory()
        let methodData = try Data(hexStringSSF: transactionPayload.method)
        let methodDecoder = try codingFactory.createDecoder(from: methodData)

        let call: WalletConnectPolkadotCall
        if let callableMethod: RuntimeCall<JSON> = try? methodDecoder.read(of: KnownType.call.rawValue) {
            call = .callable(value: callableMethod)
        } else {
            call = .raw(bytes: methodData)
        }
        return call
    }
}
