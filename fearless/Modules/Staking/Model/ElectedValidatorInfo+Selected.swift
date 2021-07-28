import Foundation

extension ElectedValidatorInfo {
    func toSelected(for nominatorAddress: AccountAddress?) -> SelectedValidatorInfo {
        let myNomination: ValidatorMyNominationStatus?

        if let nominatorAddress = nominatorAddress,
           let nominatorInfoIndex = nominators.firstIndex(where: { $0.address == nominatorAddress }) {
            let nominatorInfo = nominators[nominatorInfoIndex]
            let isRewarded = nominatorInfoIndex < maxNominatorsRewarded
            let allocations = ValidatorTokenAllocation(
                amount: nominatorInfo.stake,
                isRewarded: isRewarded
            )
            myNomination = .active(allocation: allocations)
        } else {
            myNomination = nil
        }

        return SelectedValidatorInfo(
            address: address,
            identity: identity,
            stakeInfo: ValidatorStakeInfo(
                nominators: nominators,
                totalStake: totalStake,
                stakeReturn: stakeReturn,
                maxNominatorsRewarded: maxNominatorsRewarded
            ),
            myNomination: myNomination,
            commission: comission,
            hasSlashes: hasSlashes,
            blocked: blocked
        )
    }
}
