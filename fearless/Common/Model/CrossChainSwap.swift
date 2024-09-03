import Foundation
import BigInt

protocol CrossChainSwap {
    var fromAmount: String? { get }
    var toAmount: String? { get }
    var txData: String? { get }
    var gasLimit: String? { get }
    var gasPrice: String? { get }
    var maxPriorityFeePerGas: String? { get }
    var route: String? { get }
    var crossChainFee: String? { get }
    var otherNativeFee: String? { get }
}
