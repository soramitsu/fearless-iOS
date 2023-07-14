import Foundation
import SSFModels
import Web3
import Web3ContractABI

extension ChainAsset {
    func eth() throws -> Web3.Eth {
        let isERC20 = asset.isUtility == false
        guard let rpcURL = chain.nodes.randomElement()?.url.absoluteString else {
            throw ConvenienceError(error: "cannot obtain eth rpc url for chain: \(chain.name)")
        }

        let web3eth = Web3(rpcURL: rpcURL).eth

        if isERC20 {
            let contractAddress = try EthereumAddress(hex: asset.id, eip55: false)
            let contract = web3eth.Contract(type: GenericERC20Contract.self, address: contractAddress)
            return contract.eth
        } else {
            return web3eth
        }
    }
}
