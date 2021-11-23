import FearlessUtils

struct AnalyticsValidatorItemViewModel {
    let icon: DrawableIcon?
    let validatorName: String
    let amount: Double
    let progressPercents: Double
    let mainValueText: String
    let secondaryValueText: String
    let progressFullDescription: String
    let validatorAddress: AccountAddress
}

extension AnalyticsValidatorItemViewModel: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.validatorName == rhs.validatorName
            && lhs.amount == rhs.amount
            && lhs.progressPercents == rhs.progressPercents
            && lhs.mainValueText == rhs.mainValueText
            && lhs.secondaryValueText == rhs.secondaryValueText
            && lhs.progressFullDescription == rhs.progressFullDescription
            && lhs.validatorAddress == rhs.validatorAddress
    }
}
