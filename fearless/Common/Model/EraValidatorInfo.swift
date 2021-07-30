import Foundation

struct EraStakersInfo {
    let activeEra: UInt32
    let validators: [EraValidatorInfo]
}

struct EraValidatorInfo {
    let accountId: Data
    let exposure: ValidatorExposure
    let prefs: ValidatorPrefs
}
