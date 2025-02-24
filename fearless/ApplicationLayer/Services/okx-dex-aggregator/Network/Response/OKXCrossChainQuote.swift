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

    var fromRoute: [String]? {
        let fromDexRouterList = routerList.compactMap { $0.fromDexRouterList }.reduce([], +)
        let fromRoute = fromDexRouterList.compactMap { $0.subRouterList.compactMap { [$0.fromToken.tokenSymbol.uppercased(), $0.toToken.tokenSymbol.uppercased()] }.reduce([], +) }.reduce([], +)
        
        return fromRoute
    }
    
    var toRoute: [String]? {
        let toDexRouterList = routerList.compactMap { $0.toDexRouterList }.reduce([], +)
        let toRoute = toDexRouterList.compactMap { $0.subRouterList.compactMap { [$0.fromToken.tokenSymbol.uppercased(), $0.toToken.tokenSymbol.uppercased()] }.reduce([], +) }.reduce([], +)
        
        return toRoute
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
    
    var slippage: String? {
        nil
    }
    
    var dexName: String? {
        routerList.compactMap { $0.router.bridgeName }.joined(separator: " → ")
    }
    
    var estimatedTime: String? {
        routerList.first?.estimateTime
    }
}
