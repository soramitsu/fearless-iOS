import Foundation
import Commons
import SSFUtils
import Web3
import SSFModels
import SoraKeystore
import SSFSigner

final class WalletConnectEthereumSignerImpl: WalletConnectPayloadSigner {
    enum SignType {
        case bytes(transactionSigner: TransactionSignerProtocol)
        case sendTransaction(transferService: WalletConnectEthereumTransferService, chain: ChainModel)
        case signTransaction(transferService: WalletConnectEthereumTransferService, chain: ChainModel)
    }

    private let signType: SignType

    init(signType: SignType) {
        self.signType = signType
    }

    func sign(params: AnyCodable) async throws -> AnyCodable {
        switch signType {
        case let .bytes(transactionSigner):
            return try signBytes(params, transactionSigner: transactionSigner)
        case let .sendTransaction(transferService, chain):
            return try await sendTransaction(params, chain: chain, transferService: transferService)
        case let .signTransaction(transferService, chain):
            return try signSignTransaction(params, chain: chain, transferService: transferService)
        }
    }

    // MARK: - Private methods

    private func signBytes(
        _ params: AnyCodable,
        transactionSigner: TransactionSignerProtocol
    ) throws -> AnyCodable {
        let bytes = try params.get(Data.self)
        let signedHex = try transactionSigner.sign(bytes)

        return AnyCodable(signedHex.rawData().toHex(includePrefix: true))
    }

    private func sendTransaction(
        _ params: AnyCodable,
        chain: ChainModel,
        transferService: WalletConnectEthereumTransferService
    ) async throws -> AnyCodable {
        let transactionData = try params.get(Data.self)
        let transaction = try JSONDecoder().decode(WalletConnectEthereumTransaction.self, from: transactionData)
        let web3Transaction = try transaction.mapToWeb3()

        let result = try await transferService.send(
            transaction: web3Transaction,
            chain: chain
        )

        return AnyCodable(result)
    }

    private func signSignTransaction(
        _ params: AnyCodable,
        chain: ChainModel,
        transferService: WalletConnectEthereumTransferService
    ) throws -> AnyCodable {
        let transactionData = try params.get(Data.self)
        let transaction = try JSONDecoder().decode(WalletConnectEthereumTransaction.self, from: transactionData)
        let web3Transaction = try transaction.mapToWeb3()

        let rawTransaction = try transferService.sign(
            transaction: web3Transaction,
            chain: chain
        )
        return AnyCodable(rawTransaction)
    }
}
