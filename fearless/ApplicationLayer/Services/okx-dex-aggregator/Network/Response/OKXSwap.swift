import Foundation

struct OKXSwap: Decodable {
    let routerResult: OKXQuote
    let tx: OKXSwapTransaction
}

extension OKXSwap: CrossChainTx {
    var sender: String? {
        tx.from
    }

    var amount: String? {
        routerResult.fromTokenAmount
    }

    var transactionHex: String {
        tx.data
    }

    var address: String {
        tx.to
    }
}

extension OKXSwap: CrossChainSwap {
    var contractAddress: String? {
        tx.to
    }

    var fromRoute: [String]? {
        routerResult.dexRouterList
            .compactMap { $0.subRouterList.compactMap { [$0.fromToken.tokenSymbol.uppercased(), $0.toToken.tokenSymbol.uppercased()] }.reduce([], +) }.reduce([], +)
    }
    
    var toRoute: [String]? {
        nil
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
        tx.gas
    }

    var gasPrice: String? {
        tx.gasPrice
    }

    var maxPriorityFeePerGas: String? {
        tx.maxPriorityFeePerGas
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
    
    var slippage: String? {
        tx.slippage
    }
    
    var dexName: String? {
        routerResult.quoteCompareList.sorted { quote1, quote2 in
            quote1.amountOut > quote2.amountOut
        }.first?.dexName
    }
    
    var estimatedTime: String? {
        nil
    }
}
