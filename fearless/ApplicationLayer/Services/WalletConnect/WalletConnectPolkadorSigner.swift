import Foundation
import Commons
import SSFSigner
import SSFUtils
import SSFModels

final class WalletConnectPolkadorSigner: WalletConnectPayloadSigner {
    enum SignType {
        case signTransaction(transactionSigner: TransactionSignerProtocol)
        case signMessage(transactionSigner: TransactionSignerProtocol)
    }

    private lazy var chainRegistry: ChainRegistryProtocol = {
        ChainRegistryFacade.sharedRegistry
    }()

    private lazy var operationQueue: OperationQueue = {
        OperationQueue()
    }()

    private lazy var polkadotParser: WalletConnectPolkadotParser = {
        WalletConnectPolkadorParserImpl()
    }()

    private let signType: SignType
    private let chain: ChainModel
    private let wallet: MetaAccountModel

    init(
        signType: SignType,
        chain: ChainModel,
        wallet: MetaAccountModel
    ) {
        self.signType = signType
        self.chain = chain
        self.wallet = wallet
    }

    func sign(params: AnyCodable) async throws -> AnyCodable {
        switch signType {
        case let .signTransaction(transactionSigner):
            return try await signTransaction(params, transactionSigner: transactionSigner)
        case let .signMessage(transactionSigner):
            return try signMessage(params, transactionSigner: transactionSigner)
        }
    }

    // MARK: - Private methods

    private func signTransaction(
        _ params: AnyCodable,
        transactionSigner: TransactionSignerProtocol
    ) async throws -> AnyCodable {
        let transaction = try params.get(TransactionPayload.self)
        let builder = try await createBuilder(for: transaction)
        let coderFactory = try await fetchCoderFactory()
        let signature = try builder.buildSignature(
            encodingBy: coderFactory.createEncoder(),
            metadata: coderFactory.metadata
        )
        let signedRawData = try transactionSigner.sign(signature).rawData()
        let encoded = try encode(rawData: signedRawData, encoder: coderFactory.createEncoder())
        let result = WalletConnectPolkadotSignature(
            id: UInt.random(in: 0 ..< UInt.max),
            signature: encoded.toHex(includePrefix: true)
        )
        return AnyCodable(result)
    }

    private func signMessage(
        _ params: AnyCodable,
        transactionSigner: TransactionSignerProtocol
    ) throws -> AnyCodable {
        let message = try params.get(String.self)
        let data: Data
        if message.isHex() {
            data = try Data(hexStringSSF: message)
        } else {
            guard let messageData = message.data(using: .utf8) else {
                throw ConvenienceError(error: "Can't create data from polkadot message")
            }
            data = messageData
        }

        let signedRawData = try transactionSigner.sign(data).rawData()
        let result = WalletConnectPolkadotSignature(
            id: UInt.random(in: 0 ..< UInt.max),
            signature: signedRawData.toHex(includePrefix: true)
        )
        return AnyCodable(result)
    }

    private func createBuilder(for transactionPayload: TransactionPayload) async throws -> ExtrinsicBuilderProtocol {
        let transaction = try await polkadotParser.parse(transactionPayload: transactionPayload, chain: chain)
        var builder = try ExtrinsicBuilder(
            specVersion: UInt32(transaction.specVersion),
            transactionVersion: UInt32(transaction.transactionVersion),
            genesisHash: transaction.genesisHash
        )
        .with(address: transaction.address)
        .with(nonce: UInt32(transaction.nonce))
        .with(era: transaction.era, blockHash: transaction.blockHash)

        switch transaction.method {
        case let .callable(value):
            builder = try builder.adding(call: value)
        case let .raw(bytes):
            builder = try builder.adding(rawCall: bytes)
        }

        return builder
    }

    private func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            throw RuntimeProviderError.providerUnavailable
        }
        let coderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        operationQueue.addOperation(coderFactoryOperation)
        return try await withCheckedThrowingContinuation { continuation in
            coderFactoryOperation.completionBlock = {
                do {
                    let coderFactory = try coderFactoryOperation.extractNoCancellableResultData()
                    continuation.resume(returning: coderFactory)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func fetchCryptoType() -> CryptoType {
        wallet.fetch(for: chain.accountRequest())?.cryptoType ?? .sr25519
    }

    private func encode(rawData: Data, encoder: DynamicScaleEncoding) throws -> Data {
        let cryptoType = fetchCryptoType()
        let multiSignature = MultiSignature.signature(from: cryptoType, data: rawData)
        try encoder.append(multiSignature, ofType: KnownType.signature.name)
        return try encoder.encode()
    }
}
