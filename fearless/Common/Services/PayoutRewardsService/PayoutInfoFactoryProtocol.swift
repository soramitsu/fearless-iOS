import Foundation

protocol PayoutInfoFactoryProtocol {
    func calculate(
        for accountId: AccountId,
        era: EraIndex,
        validatorInfo: EraValidatorInfo,
        erasRewardDistribution: ErasRewardDistribution,
        identities: [AccountAddress: AccountIdentity]
    ) throws -> PayoutInfo?
}
