import Foundation

struct CrossChainViewLoadingCollector {
    var originFeeReady: Bool = false
    var destinationFeeReady: Bool = false
    var balanceReady: Bool = false
    var existentialDepositReady: Bool = false
    var destinationBalanceReady: Bool = true
    var destinationExistentialDepositReady: Bool = false
    var assetAccountInfoReady: Bool = false

    mutating func reset() {
        originFeeReady = false
        destinationFeeReady = false
        balanceReady = false
        existentialDepositReady = false
        destinationBalanceReady = true
        destinationExistentialDepositReady = false
        assetAccountInfoReady = false
    }

    var isReady: Bool {
        originFeeReady && destinationFeeReady && balanceReady && existentialDepositReady && destinationBalanceReady && destinationExistentialDepositReady && assetAccountInfoReady
    }
}
