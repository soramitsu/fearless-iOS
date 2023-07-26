import Foundation
import SSFModels
import Web3
import Web3ContractABI

extension ChainModel {
    func rpcEth() throws -> Web3.Eth {
        guard let rpcURL = nodes.filter({ $0.url.absoluteString.contains("https") }).randomElement()?.url.absoluteString else {
            throw ConvenienceError(error: "cannot obtain eth rpc url for chain: \(name)")
        }

        return Web3(rpcURL: rpcURL).eth
    }

    func wsEth() throws -> Web3.Eth {
        guard let rpcURL = nodes.filter({ $0.url.absoluteString.contains("wss") }).randomElement()?.url.absoluteString else {
            throw ConvenienceError(error: "cannot obtain eth rpc url for chain: \(name)")
        }

        return try Web3(wsUrl: rpcURL).eth
    }
}
