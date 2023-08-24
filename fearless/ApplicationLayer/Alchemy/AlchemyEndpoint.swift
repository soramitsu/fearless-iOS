import Foundation

enum AlchemyEndpoint: String {
    case tokenBalances = "alchemy_getTokenBalances"
    case tokenMetadata = "alchemy_getTokenMetadata"
    case ethBalance = "eth_getBalance"
    case getAssetTransfers = "alchemy_getAssetTransfers"
    case ethGasPrice = "eth_gasPrice"
}
