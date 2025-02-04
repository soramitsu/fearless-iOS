import Foundation
import BigInt

protocol CrossChainSwap {
    var fromAmount: String? { get }
    var toAmount: String? { get }
    var txData: String? { get }
    var gasLimit: String? { get }
    var gasPrice: String? { get }
    var maxPriorityFeePerGas: String? { get }
    var fromRoute: [String]? { get }
    var toRoute: [String]? { get }
    var crossChainFee: String? { get }
    var fiatFee: String? { get }
    var contractAddress: String? { get }
    var from: String? { get }
    var fee: String? { get }
    var selectedDexId: String? { get }
    var slippage: String? { get }
    var dexName: String? { get }

    var quotes: [OKXDexQuote]? { get }
}
