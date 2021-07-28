import Foundation

extension ElectedValidatorInfo {
    func toSelected() -> SelectedValidatorInfo {
        SelectedValidatorInfo(
            address: address,
            identity: identity,
            stakeInfo: ValidatorStakeInfo(
                nominators: nominators,
                totalStake: totalStake,
                stakeReturn: stakeReturn,
                maxNominatorsRewarded: maxNominatorsRewarded
            ),
            commission: comission,
            blocked: blocked
        )
    }
}
