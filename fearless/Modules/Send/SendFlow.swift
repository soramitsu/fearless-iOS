enum SendFlowType {
    case token
    case nft
}

enum SendFlowInitialData {
    case chainAsset(ChainAsset)
    case address(String)
}
