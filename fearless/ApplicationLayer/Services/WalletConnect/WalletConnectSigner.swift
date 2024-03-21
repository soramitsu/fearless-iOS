import Foundation
import WalletConnectSign
import JSONRPC
import Commons
import SoraKeystore
import SSFModels
import SSFSigner
import SSFCrypto
import Web3

protocol WalletConnectSigner {
    func sign(
        params: AnyCodable,
        chain: ChainModel,
        method: WalletConnectMethod
    ) async throws -> AnyCodable
}

final class WalletConnectSignerImpl: WalletConnectSigner {
    private lazy var keystore: KeystoreProtocol = {
        Keychain()
    }()

    private let wallet: MetaAccountModel

    init(wallet: MetaAccountModel) {
        self.wallet = wallet
    }

    func sign(
        params: AnyCodable,
        chain: ChainModel,
        method: WalletConnectMethod
    ) async throws -> AnyCodable {
        let signer: WalletConnectPayloadSigner
        switch method {
        case .polkadotSignTransaction:
            let cryptoType = wallet.fetch(for: chain.accountRequest())?.cryptoType
            let transactionSigner = try createSigner(for: chain, cryptoType: SFCryptoType(cryptoType ?? .sr25519))
            let signType: WalletConnectPolkadorSigner.SignType = .signTransaction(transactionSigner: transactionSigner)
            signer = WalletConnectPolkadorSigner(signType: signType, chain: chain, wallet: wallet)
        case .polkadotSignMessage:
            let cryptoType = wallet.fetch(for: chain.accountRequest())?.cryptoType
            let transactionSigner = try createSigner(for: chain, cryptoType: SFCryptoType(cryptoType ?? .sr25519))
            let signType: WalletConnectPolkadorSigner.SignType = .signMessage(transactionSigner: transactionSigner)
            signer = WalletConnectPolkadorSigner(signType: signType, chain: chain, wallet: wallet)
        case .ethereumPersonalSign:
            let transactionSigner = try createSigner(for: chain, cryptoType: .ethereumEcdsa)
            let signType: WalletConnectEthereumSignerImpl.SignType = .bytes(transactionSigner: transactionSigner)
            signer = WalletConnectEthereumSignerImpl(signType: signType)
        case .ethereumSignTransaction:
            let transferService = try createEthereumTransferService(chain: chain)
            let signType: WalletConnectEthereumSignerImpl.SignType = .signTransaction(
                transferService: transferService,
                chain: chain
            )
            signer = WalletConnectEthereumSignerImpl(signType: signType)
        case .ethereumSendTransaction:
            let transferService = try createEthereumTransferService(chain: chain)
            let signType: WalletConnectEthereumSignerImpl.SignType = .sendTransaction(
                transferService: transferService,
                chain: chain
            )
            signer = WalletConnectEthereumSignerImpl(signType: signType)
        case .ethereumSignTypeData, .ethereumSignTypeDataV4:
            let transactionSigner = try createSigner(for: chain, cryptoType: .ethereumEcdsa)
            let signType: WalletConnectEthereumSignerImpl.SignType = .bytes(transactionSigner: transactionSigner)
            signer = WalletConnectEthereumSignerImpl(signType: signType)
        }

        return try await signer.sign(params: params)
    }

    // MARK: - Private methods

    private func createSigner(
        for chain: ChainModel,
        cryptoType: SFCryptoType
    ) throws -> TransactionSignerProtocol {
        let publicKeyData = try extractPublicKey(for: chain)
        let secretKeyData = try extractPrivateKey(for: chain)

        return TransactionSigner(
            publicKeyData: publicKeyData,
            secretKeyData: secretKeyData,
            cryptoType: cryptoType
        )
    }

    private func extractPrivateKey(for chain: ChainModel) throws -> Data {
        guard let accountResponse = wallet.fetch(for: chain.accountRequest()) else {
            throw AutoNamespacesError.requiredAccountsNotSatisfied
        }
        let accountId = accountResponse.isChainAccount ? accountResponse.accountId : nil
        let tag: String = chain.isEthereumBased
            ? KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)
            : KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)

        let secretKey = try keystore.fetchKey(for: tag)

        return secretKey
    }

    private func extractPublicKey(for chain: ChainModel) throws -> Data {
        guard let response = wallet.fetch(for: chain.accountRequest()) else {
            throw AutoNamespacesError.requiredAccountsNotSatisfied
        }

        return response.publicKey
    }

    private func createEthereumTransferService(
        chain: ChainModel
    ) throws -> WalletConnectEthereumTransferService {
        guard let ws = ChainRegistryFacade.sharedRegistry.getEthereumConnection(for: chain.chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        let secretKey = try extractPrivateKey(for: chain)
        let privateKey = try EthereumPrivateKey(privateKey: secretKey.bytes)

        guard let senderAddress = wallet.fetch(for: chain.accountRequest())?.toAddress() else {
            throw AutoNamespacesError.requiredAccountsNotSatisfied
        }

        return EthereumTransferService(
            ws: ws,
            privateKey: privateKey,
            senderAddress: senderAddress
        )
    }
}
