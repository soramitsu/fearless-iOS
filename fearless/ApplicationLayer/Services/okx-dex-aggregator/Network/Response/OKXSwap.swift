import Foundation

struct OKXSwap: Decodable {
    let routerResult: OKXQuote
    let tx: OKXSwapTransaction
}

extension OKXSwap: CrossChainSwap {
    var route: String? {
        routerResult.quoteCompareList.sorted { quote1, quote2 in
            quote1.amountOut > quote2.amountOut
        }.first?.dexName
    }

    var crossChainFee: String? {
        routerResult.quoteCompareList.sorted { quote1, quote2 in
            quote1.amountOut > quote2.amountOut
        }.first?.tradeFee
    }

    var otherNativeFee: String? {
        nil
    }

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
