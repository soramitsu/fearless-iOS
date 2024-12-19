
struct OKXTransactionHistoryElement: Decodable {
    let chainIndex: String?
    let txTime: String?
    let txHash: String?
    let txStatus: String?
    let txFee: String?
    let amount: String?
    let symbol: String?
    let fromDetails: OKXTransactionHistoryTokenDetails?
    let toDetails: OKXTransactionHistoryTokenDetails?
}

struct OKXTransactionHistoryTokenDetails: Decodable {
    let address: String
    let isContract: Bool
    let amount: String
}
