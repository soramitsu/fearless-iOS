import Foundation
import SSFModels
import Web3

protocol WalletConnectEthereumTransferService {
    func sign(
        transaction: EthereumTransaction,
        chain: ChainModel
    ) throws -> EthereumData

    func send(
        transaction: EthereumTransaction,
        chain: ChainModel
    ) async throws -> EthereumData
}
