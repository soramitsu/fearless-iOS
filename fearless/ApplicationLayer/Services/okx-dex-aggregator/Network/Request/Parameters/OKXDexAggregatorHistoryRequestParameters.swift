class OKXDexAggregatorHistoryRequestParameters: NetworkRequestUrlParameters, Codable {
    let chainId: String
    let txHash: String
    
    init(chainId: String, txHash: String) {
        self.chainId = chainId
        self.txHash = txHash
    }
}
