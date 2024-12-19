struct OKXWalletTransactionByHashParameters: Encodable {
    let chainIndex: String
    let txHash: String
    let iType: String?
}
