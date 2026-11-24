import Foundation
import FearlessWalletConnect
import SoraKeystore
import SSFModels
import SSFSigner
import SSFCrypto
import Web3

protocol WalletConnectSigner {
    func sign(request: WalletConnectSigningRequest) async throws -> AnyCodable
}

/// Signs exactly what a confirmation showed, with the key of the account the session
/// approved for the request's chain.
final class WalletConnectSignerImpl: WalletConnectSigner {
    private let policy: WalletConnectSigningPolicy
    private let keystore: KeystoreProtocol
    private let polkadotRuntime: WalletConnectPolkadotRuntimeProviding
    private let ethereumConnection: (ChainModel) throws -> Web3.Eth

    init(
        policy: WalletConnectSigningPolicy = .production,
        keystore: KeystoreProtocol = Keychain(),
        polkadotRuntime: WalletConnectPolkadotRuntimeProviding = WalletConnectPolkadotRuntimeProvider(),
        ethereumConnection: @escaping (ChainModel) throws -> Web3.Eth = { chain in
            guard let connection = ChainRegistryFacade.sharedRegistry.getEthereumConnection(for: chain.chainId) else {
                throw ChainRegistryError.connectionUnavailable
            }
            return connection
        }
    ) {
        self.policy = policy
        self.keystore = keystore
        self.polkadotRuntime = polkadotRuntime
        self.ethereumConnection = ethereumConnection
    }

    func sign(request: WalletConnectSigningRequest) async throws -> AnyCodable {
        // Checked before any key is read; see `WalletConnectSigningPolicy`.
        guard policy.isEnabled else {
            throw WalletConnectSigningError.unavailable
        }

        // The wallet's account for the chain must still be the one the confirmation showed.
        guard
            let account = request.wallet.fetch(for: request.chain.accountRequest()),
            account.accountId == request.account.accountId
        else {
            throw WalletConnectRequestError.accountNotApproved
        }

        let signer: WalletConnectPayloadSigner
        switch request.content {
        case let .polkadotTransaction(extrinsic):
            signer = WalletConnectPolkadorSigner(
                signType: .signTransaction(extrinsic, transactionSigner: try createSigner(for: request)),
                chain: request.chain,
                cryptoType: account.cryptoType,
                runtime: polkadotRuntime
            )
        case let .polkadotMessage(message):
            signer = WalletConnectPolkadorSigner(
                signType: .signMessage(message, transactionSigner: try createSigner(for: request)),
                chain: request.chain,
                cryptoType: account.cryptoType,
                runtime: polkadotRuntime
            )
        case let .ethereumMessage(message):
            signer = WalletConnectEthereumSignerImpl(
                signType: .message(message, transactionSigner: try createSigner(for: request))
            )
        case let .ethereumTypedData(typedData):
            signer = WalletConnectEthereumSignerImpl(
                signType: .typedData(typedData, transactionSigner: try createSigner(for: request))
            )
        case let .ethereumTransaction(quote):
            let transferService = try createEthereumTransferService(for: request)
            switch request.method {
            case .ethereumSendTransaction:
                signer = WalletConnectEthereumSignerImpl(signType: .sendTransaction(quote, transferService: transferService))
            default:
                signer = WalletConnectEthereumSignerImpl(signType: .signTransaction(quote, transferService: transferService))
            }
        }

        return try await signer.sign()
    }

    // MARK: - Private methods

    private func createSigner(for request: WalletConnectSigningRequest) throws -> TransactionSignerProtocol {
        let secretKeyData = try extractPrivateKey(for: request)

        return TransactionSignerAssembly.signer(
            for: request.chain.chainBaseType,
            publicKeyData: request.account.publicKey,
            secretKeyData: secretKeyData,
            cryptoType: request.chain.isEthereumBased ? .ecdsa : request.account.cryptoType
        )
    }

    private func extractPrivateKey(for request: WalletConnectSigningRequest) throws -> Data {
        let account = request.account
        let accountId = account.isChainAccount ? account.accountId : nil
        let tag: String = request.chain.isEthereumBased
            ? KeystoreTagV2.ethereumSecretKeyTagForMetaId(request.wallet.metaId, accountId: accountId)
            : KeystoreTagV2.substrateSecretKeyTagForMetaId(request.wallet.metaId, accountId: accountId)

        return try keystore.fetchKey(for: tag)
    }

    private func createEthereumTransferService(
        for request: WalletConnectSigningRequest
    ) throws -> WalletConnectEthereumTransferService {
        let connection = try ethereumConnection(request.chain)
        let secretKey = try extractPrivateKey(for: request)
        // web3-swift expects [UInt8]; convert Data to an Array<UInt8>
        let privateKey = try EthereumPrivateKey(privateKey: Array(secretKey))

        return EthereumTransferService(
            ws: connection,
            privateKey: privateKey,
            senderAddress: request.account.accountId.toHex(includePrefix: true)
        )
    }
}
