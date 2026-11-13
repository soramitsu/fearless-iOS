import Foundation
import FearlessWalletConnect
import SSFSigner
import SSFUtils
import SSFModels
import SSFRuntimeCodingService

final class WalletConnectPolkadorSigner: WalletConnectPayloadSigner {
    enum SignType {
        case signTransaction(WalletConnectPolkadotExtrinsic, transactionSigner: TransactionSignerProtocol)
        case signMessage(WalletConnectMessage, transactionSigner: TransactionSignerProtocol)
    }

    private let signType: SignType
    private let chain: ChainModel
    private let cryptoType: CryptoType
    private let runtime: WalletConnectPolkadotRuntimeProviding

    init(
        signType: SignType,
        chain: ChainModel,
        cryptoType: CryptoType,
        runtime: WalletConnectPolkadotRuntimeProviding
    ) {
        self.signType = signType
        self.chain = chain
        self.cryptoType = cryptoType
        self.runtime = runtime
    }

    func sign() async throws -> AnyCodable {
        switch signType {
        case let .signTransaction(extrinsic, transactionSigner):
            return try await signTransaction(extrinsic, transactionSigner: transactionSigner)
        case let .signMessage(message, transactionSigner):
            return try signMessage(message, transactionSigner: transactionSigner)
        }
    }

    // MARK: - Private methods

    private func signTransaction(
        _ extrinsic: WalletConnectPolkadotExtrinsic,
        transactionSigner: TransactionSignerProtocol
    ) async throws -> AnyCodable {
        let coderFactory = try await runtime.coderFactory(for: chain)

        // The runtime may have been upgraded while the confirmation was open; the payload
        // must still be for the runtime it was checked against.
        guard
            coderFactory.specVersion == extrinsic.specVersion,
            coderFactory.txVersion == extrinsic.transactionVersion
        else {
            throw WalletConnectRequestError.runtimeMismatch(chainName: chain.name)
        }

        let payload = try extrinsic.makeBuilder().buildSignature(
            encodingBy: coderFactory.createEncoder(),
            metadata: coderFactory.metadata
        )
        let rawSignature = try transactionSigner.sign(payload).rawData()

        let encoder = coderFactory.createEncoder()
        let multiSignature = MultiSignature.signature(from: cryptoType, data: rawSignature)
        try encoder.append(multiSignature, ofType: KnownType.signature.name)

        let result = WalletConnectPolkadotSignature(
            id: WalletConnectPolkadotSignature.makeId(),
            signature: try encoder.encode().toHex(includePrefix: true)
        )
        return AnyCodable(result)
    }

    /// Messages are signed inside the `<Bytes>` envelope, as polkadot-js signs them.
    private func signMessage(
        _ message: WalletConnectMessage,
        transactionSigner: TransactionSignerProtocol
    ) throws -> AnyCodable {
        let signedRawData = try transactionSigner.sign(WalletConnectBytesEnvelope.wrap(message.bytes)).rawData()
        let result = WalletConnectPolkadotSignature(
            id: WalletConnectPolkadotSignature.makeId(),
            signature: signedRawData.toHex(includePrefix: true)
        )
        return AnyCodable(result)
    }
}
