import Foundation

enum RPCMethod {
    static let storageSubscibe = "state_subscribeStorage"
    static let chain = "system_chain"
    static let getStorage = "state_getStorage"
    static let getStorageKeysPaged = "state_getKeysPaged"
    static let queryStorageAt = "state_queryStorageAt"
    static let getChildStorageAt = "childstate_getStorage"
    static let getBlockHash = "chain_getBlockHash"
    static let submitExtrinsic = "author_submitExtrinsic"
    static let paymentInfo = "payment_queryInfo"
    static let getRuntimeVersion = "chain_getRuntimeVersion"
    static let getRuntimeMetadata = "state_getMetadata"
    static let getChainBlock = "chain_getBlock"
    static let getFinalizedBlockHash = "chain_getFinalizedHead"
    static let getBlockHeader = "chain_getHeader"
    static let getExtrinsicNonce = "system_accountNextIndex"
    static let helthCheck = "system_health"
    static let runtimeVersionSubscribe = "state_subscribeRuntimeVersion"
}
