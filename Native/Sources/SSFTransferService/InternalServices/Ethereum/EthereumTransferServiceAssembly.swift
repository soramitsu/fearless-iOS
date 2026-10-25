import Foundation
import SSFChainRegistry
import SSFCrypto
import SSFModels
import Web3

final class EthereumTransferServiceAssembly {
    func createEthereumTransferService(
        wallet: MetaAccountModel,
        chain: ChainModel,
        secretKeyData: Data
    ) async throws -> EthereumTransferService {
        guard let accountResponse = wallet.fetch(for: chain.accountRequest()) else {
            throw TransferServiceError.accountNotExists
        }

        let chainRegistry = ChainRegistryAssembly.createDefaultRegistry()
        let connection = try await chainRegistry.getEthereumConnection(for: chain)
        let privateKey = try EthereumPrivateKey(privateKey: Array(secretKeyData))
        let address = try accountResponse.accountId.toAddress(using: .sfEthereum)

        let ethereumService = EthereumServiceDefault(connection: connection)

        let callFactory = EthereumTransferCallFactoryDefault(
            ethereumService: ethereumService,
            senderAddress: address,
            privateKey: privateKey
        )

        let transferService = EthereumTransferServiceDefault(
            privateKey: privateKey,
            senderAddress: address,
            callFactory: callFactory,
            ethereumService: ethereumService
        )
        return transferService
    }
}
