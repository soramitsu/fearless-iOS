import Foundation

struct OKXCrossChainQuote: Decodable {
    let fromChainId: String
    let fromTokenAmount: String
    let toChainId: String
    let fromToken: OKXToken
    let toToken: OKXToken
    let routerList: [OKXDexCrossChainRouter]
}

extension OKXCrossChainQuote: CrossChainSwap {
    var fiatFee: String? {
        nil
    }

    var from: String? {
        nil
    }

    var fromAmount: String? {
        fromTokenAmount
    }

    var toAmount: String? {
        routerList.first?.toTokenAmount
    }

    var txData: String? {
        nil
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

    var route: String? {
        routerList.compactMap { $0.router.bridgeName }.joined(separator: " → ")
    }

    var crossChainFee: String? {
        routerList.compactMap { Decimal(string: $0.router.crossChainFee) }.reduce(0, +).string()
    }

    var contractAddress: String? {
        routerList.first?.router.crossChainFeeTokenAddress
    }

    var quotes: [OKXDexQuote]? {
        nil
    }

    var fee: String? {
        routerList.first?.fromChainNetworkFee
    }

    var selectedDexId: String? {
        guard let bridgeId = routerList.first?.router.bridgeId else {
            return nil
        }

        return "\(bridgeId)"
    }
}
