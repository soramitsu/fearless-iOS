import Foundation

struct OKXSwap: Decodable {
    let routerResult: OKXQuote
    let tx: OKXSwapTransaction
}

extension OKXSwap: CrossChainSwap {
    var fromAmount: String? {
        routerResult.fromTokenAmount
    }
    
    var toAmount: String? {
        routerResult.toTokenAmount
    }
    
    var txData: String? {
        tx.data
    }
    
    var gasLimit: String? {
        tx.gas
    }
    
    var gasPrice: String? {
        tx.gasPrice
    }
    
    var maxPriorityFeePerGas: String? {
        tx.maxPriorityFeePerGas
    }
    
    
}
