import Foundation

struct EraStakersInfo {
    let activeEra: EraIndex
    let validators: [EraValidatorInfo]
}

struct EraValidatorInfo {
    let accountId: Data
    let exposure: ValidatorExposure
    let prefs: ValidatorPrefs
}
