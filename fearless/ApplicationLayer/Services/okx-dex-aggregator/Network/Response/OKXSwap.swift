import Foundation

struct OKXSwap: Decodable {
    let routerResult: OKXQuote
    let tx: OKXSwapTransaction
}

extension OKXSwap: CrossChainSwap {
    var contractAddress: String? {
        tx.to
    }

    var route: String? {
        routerResult.quoteCompareList.sorted { quote1, quote2 in
            quote1.amountOut > quote2.amountOut
        }.first?.dexName
    }

    var crossChainFee: String? {
        nil
    }

    var fiatFee: String? {
        routerResult.quoteCompareList.sorted { quote1, quote2 in
            quote1.amountOut > quote2.amountOut
        }.first?.tradeFee
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
        nil
    }

    var gasPrice: String? {
        nil
    }

    var maxPriorityFeePerGas: String? {
        nil
    }

    var from: String? {
        tx.from
    }

    var quotes: [OKXDexQuote]? {
        routerResult.quoteCompareList
    }

    var fee: String? {
        nil
    }

    var selectedDexId: String? {
        nil
    }
}
