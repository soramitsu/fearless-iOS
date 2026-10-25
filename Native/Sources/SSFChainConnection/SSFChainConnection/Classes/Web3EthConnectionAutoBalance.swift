import Foundation
import SSFModels
import Web3

public typealias Web3EthConnection = Web3.Eth

public final class Web3EthConnectionAutoBalance: ChainConnectionProtocol {
    public typealias T = Web3EthConnection

    public var isActive: Bool = true
    private let chain: ChainModel
    private var currentConnection: Web3EthConnection?

    public init(chain: ChainModel) {
        self.chain = chain
    }

    public func connection() throws -> Web3EthConnection {
        guard let connection = currentConnection else {
            return try setupConnection(ignoredUrl: nil)
        }
        return connection
    }

    // MARK: - Private methods

    private func setupConnection(
        ignoredUrl _: URL?
    ) throws -> Web3EthConnection {
        let ws = try EthereumNodeFetchingDefault().getNode(for: chain)
        currentConnection = ws
        return ws
    }
}
