import Foundation
import FearlessUtils
import IrohaCrypto
import BigInt

protocol SubstrateCallFactoryProtocol {
    func transfer(
        to receiver: AccountId,
        amount: BigUInt,
        chainAsset: ChainAsset
    ) -> RuntimeCall<TransferCall>

    func transfer(
        to receiver: AccountId,
        amount: BigUInt
    ) -> RuntimeCall<TransferCall>

    func bond(
        amount: BigUInt,
        controller: String,
        rewardDestination: RewardDestination<AccountAddress>
    ) throws -> RuntimeCall<BondCall>

    func bondExtra(amount: BigUInt) -> RuntimeCall<BondExtraCall>

    func unbond(amount: BigUInt) -> RuntimeCall<UnbondCall>

    func rebond(amount: BigUInt) -> RuntimeCall<RebondCall>

    func nominate(targets: [SelectedValidatorInfo]) throws -> RuntimeCall<NominateCall>

    func poolNominate(
        poolId: UInt32,
        targets: [SelectedValidatorInfo]
    ) throws -> RuntimeCall<PoolNominateCall>

    func payout(validatorId: Data, era: EraIndex) throws -> RuntimeCall<PayoutCall>

    func setPayee(for destination: RewardDestinationArg) -> RuntimeCall<SetPayeeCall>

    func withdrawUnbonded(for numberOfSlashingSpans: UInt32) -> RuntimeCall<WithdrawUnbondedCall>

    func setController(_ controller: AccountAddress) throws -> RuntimeCall<SetControllerCall>

    func chill() -> RuntimeCall<NoRuntimeArgs>

    func contribute(
        to paraId: ParaId,
        amount: BigUInt,
        multiSignature: MultiSignature?
    ) -> RuntimeCall<CrowdloanContributeCall>

    func addMemo(
        to paraId: ParaId,
        memo: Data
    ) -> RuntimeCall<CrowdloanAddMemo>

    func addRemark(_ data: Data) -> RuntimeCall<AddRemarkCall>

    func delegate(
        candidate: AccountId,
        amount: BigUInt,
        candidateDelegationCount: UInt32,
        delegationCount: UInt32
    ) -> RuntimeCall<DelegateCall>

    func delegatorBondMore(
        candidate: AccountId,
        amount: BigUInt
    ) -> RuntimeCall<DelegatorBondMoreCall>

    func scheduleDelegatorBondLess(
        candidate: AccountId,
        amount: BigUInt
    ) -> RuntimeCall<ScheduleDelegatorBondLessCall>

    func scheduleRevokeDelegation(
        candidate: AccountId
    ) -> RuntimeCall<ScheduleRevokeDelegationCall>

    func executeDelegationRequest(
        delegator: AccountId,
        collator: AccountId
    ) -> RuntimeCall<ExecuteDelegationRequestCall>

    func cancelCandidateBondLess() -> RuntimeCall<NoRuntimeArgs>

    func cancelDelegationRequest(candidate: AccountId) -> RuntimeCall<CancelDelegationRequestCall>

    func cancelLeaveDelegators() -> RuntimeCall<NoRuntimeArgs>

    func candidateBondMore(
        amount: BigUInt
    ) -> RuntimeCall<CandidateBondMoreCall>

    func scheduleCandidateBondLess(amount: BigUInt) -> RuntimeCall<ScheduleCandidateBondLessCall>

    func joinPool(
        poolId: String,
        amount: BigUInt
    ) -> RuntimeCall<JoinPoolCall>

    func createPool(
        amount: BigUInt,
        root: MultiAddress,
        nominator: MultiAddress,
        stateToggler: MultiAddress
    ) -> RuntimeCall<CreatePoolCall>

    func setPoolMetadata(
        poolId: String,
        metadata: Data
    ) -> RuntimeCall<SetMetadataCall>

    func poolBondMore(amount: BigUInt) -> RuntimeCall<PoolBondMoreCall>

    func poolUnbond(accountId: AccountId, amount: BigUInt) -> RuntimeCall<PoolUnbondCall>

    func claimPoolRewards() -> RuntimeCall<NoRuntimeArgs>

    func poolWithdrawUnbonded(accountId: AccountId, numSlashingSpans: UInt32) -> RuntimeCall<PoolWithdrawUnbondedCall>
}

// swiftlint:disable type_body_length file_length
final class SubstrateCallFactory: SubstrateCallFactoryProtocol {
    private let addressFactory = SS58AddressFactory()

    // MARK: - Public methods

    func bond(
        amount: BigUInt,
        controller: String,
        rewardDestination: RewardDestination<String>
    ) throws -> RuntimeCall<BondCall> {
        let controllerId = try addressFactory.accountId(from: controller)

        let destArg: RewardDestinationArg

        switch rewardDestination {
        case .restake:
            destArg = .staked
        case let .payout(address):
            let accountId = try addressFactory.accountId(from: address)
            destArg = .account(accountId)
        }

        let args = BondCall(
            controller: .accoundId(controllerId),
            value: amount,
            payee: destArg
        )

        let path: SubstrateCallPath = .bond
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func bondExtra(amount: BigUInt) -> RuntimeCall<BondExtraCall> {
        let args = BondExtraCall(amount: amount)
        let path: SubstrateCallPath = .bondExtra
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func unbond(amount: BigUInt) -> RuntimeCall<UnbondCall> {
        let args = UnbondCall(amount: amount)
        let path: SubstrateCallPath = .unbond
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func rebond(amount: BigUInt) -> RuntimeCall<RebondCall> {
        let args = RebondCall(amount: amount)
        let path: SubstrateCallPath = .rebond
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func nominate(targets: [SelectedValidatorInfo]) throws -> RuntimeCall<NominateCall> {
        let addresses: [MultiAddress] = try targets.map { info in
            let accountId = try addressFactory.accountId(from: info.address)
            return MultiAddress.accoundId(accountId)
        }

        let args = NominateCall(targets: addresses)

        let path: SubstrateCallPath = .nominate
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func poolNominate(
        poolId: UInt32,
        targets: [SelectedValidatorInfo]
    ) throws -> RuntimeCall<PoolNominateCall> {
        let addresses: [AccountId] = try targets.map { info in
            try info.address.toAccountId()
        }

        let args = PoolNominateCall(pool_id: "\(poolId)", validators: addresses)

        return RuntimeCall(moduleName: "NominationPools", callName: "nominate", args: args)
    }

    func payout(validatorId: Data, era: EraIndex) throws -> RuntimeCall<PayoutCall> {
        let args = PayoutCall(
            validatorStash: validatorId,
            era: era
        )

        let path: SubstrateCallPath = .payout
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func transfer(
        to receiver: AccountId,
        amount: BigUInt,
        chainAsset: ChainAsset
    ) -> RuntimeCall<TransferCall> {
        switch chainAsset.chainAssetType {
        case .normal:
            return defaultTransfer(to: receiver, amount: amount)
        case .ormlChain:
            return ormlChainTransfer(to: receiver, amount: amount, currencyId: chainAsset.currencyId)
        case
            .ormlAsset,
            .foreignAsset,
            .stableAssetPoolToken,
            .liquidCrowdloan,
            .vToken,
            .vsToken,
            .stable:
            return ormlAssetTransfer(to: receiver, amount: amount, currencyId: chainAsset.currencyId)
        case .equilibrium:
            return equilibriumAssetTransfer(to: receiver, amount: amount, currencyId: chainAsset.currencyId)
        }
    }

    func transfer(to receiver: AccountId, amount: BigUInt) -> RuntimeCall<TransferCall> {
        let args = TransferCall(dest: .accoundId(receiver), value: amount, currencyId: nil)
        let path: SubstrateCallPath = .transfer
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func setPayee(for destination: RewardDestinationArg) -> RuntimeCall<SetPayeeCall> {
        let args = SetPayeeCall(payee: destination)
        let path: SubstrateCallPath = .setPayee
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func withdrawUnbonded(for numberOfSlashingSpans: UInt32) -> RuntimeCall<WithdrawUnbondedCall> {
        let args = WithdrawUnbondedCall(numberOfSlashingSpans: numberOfSlashingSpans)
        let path: SubstrateCallPath = .withdrawUnbonded
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func setController(_ controller: AccountAddress) throws -> RuntimeCall<SetControllerCall> {
        let controllerId = try addressFactory.accountId(from: controller)
        let args = SetControllerCall(controller: .accoundId(controllerId))
        let path: SubstrateCallPath = .setController
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func chill() -> RuntimeCall<NoRuntimeArgs> {
        let path: SubstrateCallPath = .chill
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName
        )
    }

    func contribute(
        to paraId: ParaId,
        amount: BigUInt,
        multiSignature: MultiSignature? = nil
    ) -> RuntimeCall<CrowdloanContributeCall> {
        let args = CrowdloanContributeCall(index: paraId, value: amount, signature: multiSignature)
        let path: SubstrateCallPath = .contribute
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func addMemo(to paraId: ParaId, memo: Data) -> RuntimeCall<CrowdloanAddMemo> {
        let args = CrowdloanAddMemo(index: paraId, memo: memo)
        let path: SubstrateCallPath = .addMemo
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func addRemark(_ data: Data) -> RuntimeCall<AddRemarkCall> {
        let args = AddRemarkCall(remark: data)
        let path: SubstrateCallPath = .addRemark
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func delegate(
        candidate: AccountId,
        amount: BigUInt,
        candidateDelegationCount: UInt32,
        delegationCount: UInt32
    ) -> RuntimeCall<DelegateCall> {
        let args = DelegateCall(
            candidate: candidate,
            amount: amount,
            candidateDelegationCount: candidateDelegationCount,
            delegationCount: delegationCount
        )

        let path: SubstrateCallPath = .delegate
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func delegatorBondMore(
        candidate: AccountId,
        amount: BigUInt
    ) -> RuntimeCall<DelegatorBondMoreCall> {
        let args = DelegatorBondMoreCall(candidate: candidate, more: amount)

        let path: SubstrateCallPath = .delegatorBondMore
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func scheduleDelegatorBondLess(
        candidate: AccountId,
        amount: BigUInt
    ) -> RuntimeCall<ScheduleDelegatorBondLessCall> {
        let args = ScheduleDelegatorBondLessCall(candidate: candidate, less: amount)

        let path: SubstrateCallPath = .scheduleCandidateBondLess
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func scheduleRevokeDelegation(candidate: AccountId) -> RuntimeCall<ScheduleRevokeDelegationCall> {
        let args = ScheduleRevokeDelegationCall(collator: candidate)

        let path: SubstrateCallPath = .scheduleRevokeDelegation
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func executeDelegationRequest(
        delegator: AccountId,
        collator: AccountId
    ) -> RuntimeCall<ExecuteDelegationRequestCall> {
        let args = ExecuteDelegationRequestCall(delegator: delegator, candidate: collator)

        let path: SubstrateCallPath = .executeDelegationRequest
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func cancelCandidateBondLess() -> RuntimeCall<NoRuntimeArgs> {
        let path: SubstrateCallPath = .cancelCandidateBondLess
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName
        )
    }

    func cancelDelegationRequest(candidate: AccountId) -> RuntimeCall<CancelDelegationRequestCall> {
        let args = CancelDelegationRequestCall(candidate: candidate)

        let path: SubstrateCallPath = .cancelDelegationRequest
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func cancelLeaveDelegators() -> RuntimeCall<NoRuntimeArgs> {
        let path: SubstrateCallPath = .cancelLeaveDelegators
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName
        )
    }

    func candidateBondMore(amount: BigUInt) -> RuntimeCall<CandidateBondMoreCall> {
        let args = CandidateBondMoreCall(more: amount)
        let path: SubstrateCallPath = .candidateBondMore
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func scheduleCandidateBondLess(amount: BigUInt) -> RuntimeCall<ScheduleCandidateBondLessCall> {
        let args = ScheduleCandidateBondLessCall(less: amount)
        let path: SubstrateCallPath = .scheduleCandidateBondLess
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func joinPool(
        poolId: String,
        amount: BigUInt
    ) -> RuntimeCall<JoinPoolCall> {
        let args = JoinPoolCall(amount: amount, poolId: poolId)

        return RuntimeCall(
            callCodingPath: .nominationPoolJoin,
            args: args
        )
    }

    func createPool(
        amount: BigUInt,
        root: MultiAddress,
        nominator: MultiAddress,
        stateToggler: MultiAddress
    ) -> RuntimeCall<CreatePoolCall> {
        let args = CreatePoolCall(
            amount: amount,
            root: root,
            nominator: nominator,
            stateToggler: stateToggler
        )

        return RuntimeCall(
            callCodingPath: .createNominationPool,
            args: args
        )
    }

    func setPoolMetadata(
        poolId: String,
        metadata: Data
    ) -> RuntimeCall<SetMetadataCall> {
        let args = SetMetadataCall(
            poolId: poolId,
            metadata: metadata
        )

        return RuntimeCall(
            callCodingPath: .setPoolMetadata,
            args: args
        )
    }

    func poolBondMore(amount: BigUInt) -> RuntimeCall<PoolBondMoreCall> {
        let args = PoolBondMoreCall(
            extra: .freeBalance(amount: amount)
        )

        return RuntimeCall(
            callCodingPath: .poolBondMore,
            args: args
        )
    }

    func poolUnbond(accountId: AccountId, amount: BigUInt) -> RuntimeCall<PoolUnbondCall> {
        let args = PoolUnbondCall(
            memberAccount: .accoundId(accountId),
            unbondingPoints: amount
        )

        return RuntimeCall(
            callCodingPath: .poolUnbond,
            args: args
        )
    }

    func poolUnbondOld(accountId: AccountId, amount: BigUInt) -> RuntimeCall<PoolUnbondCallOld> {
        let args = PoolUnbondCallOld(
            memberAccount: accountId,
            unbondingPoints: amount
        )

        return RuntimeCall(
            callCodingPath: .poolUnbond,
            args: args
        )
    }

    func poolWithdrawUnbonded(accountId: AccountId, numSlashingSpans: UInt32) -> RuntimeCall<PoolWithdrawUnbondedCall> {
        let args = PoolWithdrawUnbondedCall(
            memberAccount: .accoundId(accountId),
            numSlashingSpans: numSlashingSpans
        )

        return RuntimeCall(
            callCodingPath: .poolWithdrawUnbonded,
            args: args
        )
    }

    func claimPoolRewards() -> RuntimeCall<NoRuntimeArgs> {
        RuntimeCall(
            moduleName: CallCodingPath.claimPendingRewards.moduleName,
            callName: CallCodingPath.claimPendingRewards.callName
        )
    }

    // MARK: - Private methods

    private func ormlChainTransfer(
        to receiver: AccountId,
        amount: BigUInt,
        currencyId: CurrencyId?
    ) -> RuntimeCall<TransferCall> {
        let args = TransferCall(dest: .accoundId(receiver), value: amount, currencyId: currencyId)
        let path: SubstrateCallPath = .ormlChainTransfer
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    private func ormlAssetTransfer(
        to receiver: AccountId,
        amount: BigUInt,
        currencyId: CurrencyId?
    ) -> RuntimeCall<TransferCall> {
        let args = TransferCall(dest: .accoundId(receiver), value: amount, currencyId: currencyId)
        let path: SubstrateCallPath = .ormlAssetTransfer
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    private func equilibriumAssetTransfer(
        to receiver: AccountId,
        amount: BigUInt,
        currencyId: CurrencyId?
    ) -> RuntimeCall<TransferCall> {
        let args = TransferCall(dest: .accountTo(receiver), value: amount, currencyId: currencyId)
        let path: SubstrateCallPath = .equilibriumAssetTransfer
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    private func defaultTransfer(
        to receiver: AccountId,
        amount: BigUInt
    ) -> RuntimeCall<TransferCall> {
        let args = TransferCall(dest: .accoundId(receiver), value: amount, currencyId: nil)
        let path: SubstrateCallPath = .defaultTransfer
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }
}

// MARK: - extension SubstrateCallFactory

extension SubstrateCallFactory {
    func setRewardDestination(
        _ rewardDestination: RewardDestination<AccountAddress>,
        stashItem: StashItem
    ) throws -> RuntimeCall<SetPayeeCall> {
        let arg: RewardDestinationArg = try {
            switch rewardDestination {
            case .restake:
                return .staked
            case let .payout(accountAddress):
                if accountAddress == stashItem.stash {
                    return .stash
                }

                if accountAddress == stashItem.controller {
                    return .controller
                }

                let accountId = try SS58AddressFactory().accountId(from: accountAddress)

                return .account(accountId)
            }
        }()

        return setPayee(for: arg)
    }
}
