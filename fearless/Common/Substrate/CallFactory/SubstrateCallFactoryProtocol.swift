import Foundation
import SSFUtils
import IrohaCrypto
import BigInt
import SSFModels

protocol SubstrateCallFactoryProtocol {
    func transfer(
        to receiver: AccountId,
        amount: BigUInt,
        chainAsset: ChainAsset
    ) -> any RuntimeCallable
    func transfer(
        to receiver: AccountId,
        amount: BigUInt
    ) -> any RuntimeCallable
    func xorlessTransfer(_ transfer: XorlessTransfer) -> any RuntimeCallable
    func bond(
        amount: BigUInt,
        controller: String,
        rewardDestination: RewardDestination<AccountAddress>,
        chainAsset: ChainAsset
    ) throws -> any RuntimeCallable
    func bondExtra(amount: BigUInt) -> any RuntimeCallable
    func unbond(amount: BigUInt) -> any RuntimeCallable
    func rebond(amount: BigUInt) -> any RuntimeCallable
    func nominate(targets: [SelectedValidatorInfo], chainAsset: ChainAsset) throws -> any RuntimeCallable
    func poolNominate(
        poolId: UInt32,
        targets: [SelectedValidatorInfo]
    ) throws -> any RuntimeCallable
    func payout(validatorId: Data, era: EraIndex) throws -> any RuntimeCallable
    func setPayee(for destination: RewardDestinationArg) -> any RuntimeCallable
    func withdrawUnbonded(for numberOfSlashingSpans: UInt32) -> any RuntimeCallable
    func setController(_ controller: AccountAddress, chainAsset: ChainAsset) throws -> any RuntimeCallable
    func chill() -> any RuntimeCallable
    func contribute(
        to paraId: ParaId,
        amount: BigUInt,
        multiSignature: MultiSignature?
    ) -> any RuntimeCallable
    func addMemo(
        to paraId: ParaId,
        memo: Data
    ) -> any RuntimeCallable
    func addRemark(_ data: Data) -> any RuntimeCallable
    func delegate(
        candidate: AccountId,
        amount: BigUInt,
        candidateDelegationCount: UInt32,
        delegationCount: UInt32
    ) -> any RuntimeCallable
    func delegatorBondMore(
        candidate: AccountId,
        amount: BigUInt
    ) -> any RuntimeCallable
    func scheduleDelegatorBondLess(
        candidate: AccountId,
        amount: BigUInt
    ) -> any RuntimeCallable
    func scheduleRevokeDelegation(
        candidate: AccountId
    ) -> any RuntimeCallable
    func executeDelegationRequest(
        delegator: AccountId,
        collator: AccountId
    ) -> any RuntimeCallable
    func cancelCandidateBondLess() -> any RuntimeCallable
    func cancelDelegationRequest(candidate: AccountId) -> any RuntimeCallable
    func cancelLeaveDelegators() -> any RuntimeCallable
    func candidateBondMore(
        amount: BigUInt
    ) -> any RuntimeCallable
    func scheduleCandidateBondLess(amount: BigUInt) -> any RuntimeCallable
    func joinPool(
        poolId: String,
        amount: BigUInt
    ) -> any RuntimeCallable
    func createPool(
        amount: BigUInt,
        root: MultiAddress,
        nominator: MultiAddress,
        bouncer: MultiAddress
    ) throws -> any RuntimeCallable
    func setPoolMetadata(
        poolId: String,
        metadata: Data
    ) -> any RuntimeCallable
    func poolBondMore(amount: BigUInt) -> any RuntimeCallable
    func poolUnbond(accountId: AccountId, amount: BigUInt) -> any RuntimeCallable
    func claimPoolRewards() -> any RuntimeCallable
    func poolWithdrawUnbonded(accountId: AccountId, numSlashingSpans: UInt32) -> any RuntimeCallable
    func nominationPoolUpdateRoles(
        poolId: String,
        roles: StakingPoolRoles
    ) -> any RuntimeCallable
    func swap(
        dexId: String,
        from asset: String,
        to targetAsset: String,
        amountCall: [SwapVariant: SwapAmount],
        type: [[String?]],
        filter: Int
    ) -> any RuntimeCallable
    func poolUnbondOld(
        accountId: AccountId,
        amount: BigUInt
    ) -> any RuntimeCallable
    func setRewardDestination(
        _ rewardDestination: RewardDestination<AccountAddress>,
        stashItem: StashItem,
        chainAsset: ChainAsset
    ) throws -> any RuntimeCallable
}
