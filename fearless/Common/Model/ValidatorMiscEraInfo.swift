import Foundation

struct ValidatorMiscEraInfo {
    let erasItems: ErasItems<ValidatorPrefs>
    let ledgers: [Data: StakingLedger]
}
