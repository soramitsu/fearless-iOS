import Foundation

struct StakingRewardHistoryCellViewModel: Equatable {
    let addressOrName: String
    let daysLeftText: NSAttributedString
    let tokenAmountText: String
    let usdAmountText: String?
    let timeInterval: TimeInterval?
    let locale: Locale
}
