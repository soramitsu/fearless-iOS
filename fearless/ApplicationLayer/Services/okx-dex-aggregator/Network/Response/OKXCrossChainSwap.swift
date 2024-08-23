import Foundation

struct OKXCrossChainSwap: Decodable {
    let fromTokenAmount: String?
    let router: OKXCrossChainRouter
    let toTokenAmount: String?
    let minimumReceive: String?
    let tx: OKXCrossChainSwapTransaction
}

extension OKXCrossChainSwap: CrossChainSwap {
    var fromAmount: String? {
        fromTokenAmount
    }

    var toAmount: String? {
        toTokenAmount
    }

    var txData: String? {
        tx.data
    }

    var gasLimit: String? {
        tx.gasLimit
    }

    var gasPrice: String? {
        tx.gasPrice
    }

    var maxPriorityFeePerGas: String? {
        tx.maxPriorityFeePerGas
    }
}
