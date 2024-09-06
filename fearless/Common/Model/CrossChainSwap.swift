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

    var totalFees: BigUInt? { get }
}

extension CrossChainSwap {
    var totalFees: BigUInt? {
        let gasPrice = gasPrice.flatMap { BigUInt(string: $0) }
        let gasLimit = gasLimit.flatMap { BigUInt(string: $0) }

        let fee: BigUInt? = gasPrice.flatMap {
            guard let gasLimit else {
                return nil
            }

            return $0 * gasLimit
        }

        let crossChainFee = crossChainFee.flatMap { BigUInt(string: $0) }
        let otherNativeFee = otherNativeFee.flatMap { BigUInt(string: $0) }

        return fee.or(.zero)
    }
}
