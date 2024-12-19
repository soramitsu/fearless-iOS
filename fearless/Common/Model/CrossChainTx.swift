protocol CrossChainTx {
    var amount: String? { get }
    var transactionHex: String { get }
    var address: String { get }
    var gasLimit: String? { get }
    var gasPrice: String? { get }
    var maxPriorityFeePerGas: String? { get }
    var sender: String? { get }
}
