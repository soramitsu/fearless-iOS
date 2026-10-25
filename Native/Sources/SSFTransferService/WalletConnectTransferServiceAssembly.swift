import Foundation
import SSFChainRegistry
import SSFModels
import Web3

public class WalletConnectTransferServiceAssembly {
    public func createService(
        privateKey: Data,
        chain: ChainModel
    ) async throws -> WalletConnectTransferService {
        let chainRegistry = ChainRegistryAssembly.createDefaultRegistry()
        let connection = try await chainRegistry.getEthereumConnection(for: chain)
        let privateKey = try EthereumPrivateKey(privateKey: Array(privateKey))
        let ethereumService = EthereumServiceDefault(connection: connection)

        let service = WalletConnectTransferServiceDefault(
            privateKey: privateKey,
            ethereumService: ethereumService
        )
        return service
    }
}
