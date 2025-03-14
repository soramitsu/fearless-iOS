import Foundation

struct OKXCrossChainSwap: Decodable {
    let fromTokenAmount: String?
    let router: OKXCrossChainRouter
    let toTokenAmount: String?
    let minimumReceive: String?
    let tx: OKXCrossChainSwapTransaction
}

extension OKXCrossChainSwap: CrossChainTx {
    var gasLimit: String? {
        tx.gasLimit
    }

    var gasPrice: String? {
        tx.gasPrice
    }

    var maxPriorityFeePerGas: String? {
        tx.maxPriorityFeePerGas
    }

    var sender: String? {
        tx.from
    }

    var amount: String? {
        tx.value
    }

    var transactionHex: String {
        tx.data
    }

    var address: String {
        tx.to
    }
}
