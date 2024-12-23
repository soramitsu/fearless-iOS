final class OKXWalletTransactionByHashParameters: NetworkRequestUrlParameters, Decodable {
    let chainIndex: String
    let txHash: String
    let iType: String?

    init(chainIndex: String, txHash: String, iType: String?) {
        self.chainIndex = chainIndex
        self.txHash = txHash
        self.iType = iType
    }
}
