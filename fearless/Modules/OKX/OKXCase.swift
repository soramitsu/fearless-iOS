import SSFModels

enum OKXCase {
    case swap(chainAsset: ChainAsset)
    case bridge

    init(fromChainAsset: ChainAsset, toChainAsset: ChainAsset) {
        if fromChainAsset.chain.chainId == toChainAsset.chain.chainId {
            self = .swap(chainAsset: fromChainAsset)
        } else {
            self = .bridge
        }
    }
}
