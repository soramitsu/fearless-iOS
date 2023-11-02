import Foundation
import WalletConnectUtils
import SSFModels

struct WalletConnectChainsResolution {
    let requiredChains: ChainsResolution
    let optionalChains: ChainsResolution

    func allBlockChains() -> [BlockChain] {
        requiredChains.allowed + optionalChains.allowed
    }
}

struct ChainsResolution {
    var allowed: [BlockChain]
    var forbidden: Set<Blockchain>
}

struct BlockChain {
    let blockchain: Blockchain
    let chain: ChainModel
}
