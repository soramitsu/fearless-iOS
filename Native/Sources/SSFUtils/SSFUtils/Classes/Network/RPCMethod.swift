import Foundation

public enum RPCMethod {
    public static let storageSubscribe = "state_subscribeStorage"
    public static let chain = "system_chain"
    public static let getStorage = "state_getStorage"
    public static let getStorageKeysPaged = "state_getKeysPaged"
    public static let queryStorageAt = "state_queryStorageAt"
    public static let getChildStorageAt = "childstate_getStorage"
    public static let getBlockHash = "chain_getBlockHash"
    public static let submitExtrinsic = "author_submitExtrinsic"
    public static let submitAndWatchExtrinsic = "author_submitAndWatchExtrinsic"
    public static let paymentInfo = "payment_queryFeeDetails"
    public static let getRuntimeVersion = "chain_getRuntimeVersion"
    public static let getRuntimeMetadata = "state_getMetadata"
    public static let getChainBlock = "chain_getBlock"
    public static let getFinalizedBlockHash = "chain_getFinalizedHead"
    public static let getBlockHeader = "chain_getHeader"
    public static let getExtrinsicNonce = "system_accountNextIndex"
    public static let helthCheck = "system_health"
    public static let runtimeVersionSubscribe = "state_subscribeRuntimeVersion"
    public static let existentialDeposit = "tokens_queryExistentialDeposit"
    public static let stateCall = "state_call"
    public static let stateUnsubscribe = "state_unsubscribeStorage"

    // Polkaswap
    public static let checkIsSwapPossible = "liquidityProxy_isPathAvailable"
    public static let availableMarketAlgorithms = "liquidityProxy_listEnabledSourcesForPath"
    public static let recalculateSwapValues = "liquidityProxy_quote"
    public static let swapExtrinsic = "liquidityProxy_swap"
    public static let listSupportedSources = "dexApi_listSupportedSources"

    public static let accountPools = "PoolXYK_AccountPools"
    public static let isPairEnabled = "tradingPair_isPairEnabled"
}
