import Foundation

struct PayoutsInfo {
    let activeEra: EraIndex
    let payouts: [PayoutInfo]
}

struct PayoutInfo {
    let era: EraIndex
    let validator: Data
    let reward: Decimal
}
