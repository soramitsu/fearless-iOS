import Foundation

struct CrossChainViewLoadingCollector {
    var originFeeReady: Bool?
    var destinationFeeReady: Bool?
    var balanceReady: Bool = false
    var existentialDepositReady: Bool = false
    var destinationBalanceReady: Bool = false
    var destinationExistentialDepositReady: Bool = false
    var assetAccountInfoReady: Bool = false
    var addressExists: Bool = false

    mutating func reset() {
        originFeeReady = false
        destinationFeeReady = false
        balanceReady = false
        existentialDepositReady = false
        destinationBalanceReady = false
        destinationExistentialDepositReady = false
        assetAccountInfoReady = false
        addressExists = false
    }

    var isReady: Bool? {
        guard let originFeeReady, let destinationFeeReady else {
            return nil
        }
        let destinationReady = addressExists ? destinationBalanceReady : true
        return [
            originFeeReady,
            destinationFeeReady,
            balanceReady,
            existentialDepositReady,
            destinationReady,
            destinationExistentialDepositReady,
            assetAccountInfoReady
        ].allSatisfy { $0 }
    }
}
