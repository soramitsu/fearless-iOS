import Foundation

struct EraStakersInfo {
    let era: UInt32
    let validators: [EraValidatorInfo]
}

struct EraValidatorInfo {
    let accountId: Data
    let exposure: ValidatorExposure
    let prefs: ValidatorPrefs
}
