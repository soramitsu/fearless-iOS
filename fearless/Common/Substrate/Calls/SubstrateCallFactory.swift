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
        root: AccountId,
        nominator: AccountId,
        stateToggler: AccountId
    ) -> RuntimeCall<CreatePoolCall>

    func setPoolMetadata(
        poolId: String,
        metadata: Data
    ) -> RuntimeCall<SetMetadataCall>
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

        return RuntimeCall(moduleName: "Staking", callName: "bond", args: args)
    }

    func bondExtra(amount: BigUInt) -> RuntimeCall<BondExtraCall> {
        let args = BondExtraCall(amount: amount)
        return RuntimeCall(moduleName: "Staking", callName: "bond_extra", args: args)
    }

    func unbond(amount: BigUInt) -> RuntimeCall<UnbondCall> {
        let args = UnbondCall(amount: amount)
        return RuntimeCall(moduleName: "Staking", callName: "unbond", args: args)
    }

    func rebond(amount: BigUInt) -> RuntimeCall<RebondCall> {
        let args = RebondCall(amount: amount)
        return RuntimeCall(moduleName: "Staking", callName: "rebond", args: args)
    }

    func nominate(targets: [SelectedValidatorInfo]) throws -> RuntimeCall<NominateCall> {
        let addresses: [MultiAddress] = try targets.map { info in
            let accountId = try addressFactory.accountId(from: info.address)
            return MultiAddress.accoundId(accountId)
        }

        let args = NominateCall(targets: addresses)

        return RuntimeCall(moduleName: "Staking", callName: "nominate", args: args)
    }

    func payout(validatorId: Data, era: EraIndex) throws -> RuntimeCall<PayoutCall> {
        let args = PayoutCall(
            validatorStash: validatorId,
            era: era
        )

        return RuntimeCall(moduleName: "Staking", callName: "payout_stakers", args: args)
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
        return RuntimeCall(moduleName: "Balances", callName: "transfer", args: args)
    }

    func setPayee(for destination: RewardDestinationArg) -> RuntimeCall<SetPayeeCall> {
        let args = SetPayeeCall(payee: destination)
        return RuntimeCall(moduleName: "Staking", callName: "set_payee", args: args)
    }

    func withdrawUnbonded(for numberOfSlashingSpans: UInt32) -> RuntimeCall<WithdrawUnbondedCall> {
        let args = WithdrawUnbondedCall(numberOfSlashingSpans: numberOfSlashingSpans)
        return RuntimeCall(moduleName: "Staking", callName: "withdraw_unbonded", args: args)
    }

    func setController(_ controller: AccountAddress) throws -> RuntimeCall<SetControllerCall> {
        let controllerId = try addressFactory.accountId(from: controller)
        let args = SetControllerCall(controller: .accoundId(controllerId))
        return RuntimeCall(moduleName: "Staking", callName: "set_controller", args: args)
    }

    func chill() -> RuntimeCall<NoRuntimeArgs> {
        RuntimeCall(moduleName: "Staking", callName: "chill")
    }

    func contribute(
        to paraId: ParaId,
        amount: BigUInt,
        multiSignature: MultiSignature? = nil
    ) -> RuntimeCall<CrowdloanContributeCall> {
        let args = CrowdloanContributeCall(index: paraId, value: amount, signature: multiSignature)
        return RuntimeCall(moduleName: "Crowdloan", callName: "contribute", args: args)
    }

    func addMemo(to paraId: ParaId, memo: Data) -> RuntimeCall<CrowdloanAddMemo> {
        let args = CrowdloanAddMemo(index: paraId, memo: memo)
        return RuntimeCall(moduleName: "Crowdloan", callName: "add_memo", args: args)
    }

    func addRemark(_ data: Data) -> RuntimeCall<AddRemarkCall> {
        let args = AddRemarkCall(remark: data)
        return RuntimeCall(moduleName: "System", callName: "remark", args: args)
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

        return RuntimeCall(
            moduleName: "ParachainStaking",
            callName: "Delegate",
            args: args
        )
    }

    func delegatorBondMore(
        candidate: AccountId,
        amount: BigUInt
    ) -> RuntimeCall<DelegatorBondMoreCall> {
        let args = DelegatorBondMoreCall(candidate: candidate, more: amount)

        return RuntimeCall(
            moduleName: "ParachainStaking",
            callName: "delegator_bond_more",
            args: args
        )
    }

    func scheduleDelegatorBondLess(
        candidate: AccountId,
        amount: BigUInt
    ) -> RuntimeCall<ScheduleDelegatorBondLessCall> {
        let args = ScheduleDelegatorBondLessCall(candidate: candidate, less: amount)

        return RuntimeCall(
            moduleName: "ParachainStaking",
            callName: "schedule_delegator_bond_less",
            args: args
        )
    }

    func scheduleRevokeDelegation(candidate: AccountId) -> RuntimeCall<ScheduleRevokeDelegationCall> {
        let args = ScheduleRevokeDelegationCall(collator: candidate)

        return RuntimeCall(
            moduleName: "ParachainStaking",
            callName: "schedule_revoke_delegation",
            args: args
        )
    }

    func executeDelegationRequest(
        delegator: AccountId,
        collator: AccountId
    ) -> RuntimeCall<ExecuteDelegationRequestCall> {
        let args = ExecuteDelegationRequestCall(delegator: delegator, candidate: collator)

        return RuntimeCall(
            moduleName: "ParachainStaking",
            callName: "execute_delegation_request",
            args: args
        )
    }

    func cancelCandidateBondLess() -> RuntimeCall<NoRuntimeArgs> {
        RuntimeCall(
            moduleName: "ParachainStaking",
            callName: "cancel_candidate_bond_less"
        )
    }

    func cancelDelegationRequest(candidate: AccountId) -> RuntimeCall<CancelDelegationRequestCall> {
        let args = CancelDelegationRequestCall(candidate: candidate)

        return RuntimeCall(
            moduleName: "ParachainStaking",
            callName: "cancel_delegation_request",
            args: args
        )
    }

    func cancelLeaveDelegators() -> RuntimeCall<NoRuntimeArgs> {
        RuntimeCall(moduleName: "ParachainStaking", callName: "cancel_leave_delegators")
    }

    func candidateBondMore(amount: BigUInt) -> RuntimeCall<CandidateBondMoreCall> {
        let args = CandidateBondMoreCall(more: amount)
        return RuntimeCall(
            moduleName: "ParachainStaking",
            callName: "candidate_bond_more",
            args: args
        )
    }

    func scheduleCandidateBondLess(amount: BigUInt) -> RuntimeCall<ScheduleCandidateBondLessCall> {
        let args = ScheduleCandidateBondLessCall(less: amount)
        return RuntimeCall(
            moduleName: "ParachainStaking",
            callName: "schedule_candidate_bond_less",
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
        root: AccountId,
        nominator: AccountId,
        stateToggler: AccountId
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

    // MARK: - Private methods

    private func ormlChainTransfer(
        to receiver: AccountId,
        amount: BigUInt,
        currencyId: CurrencyId?
    ) -> RuntimeCall<TransferCall> {
        let args = TransferCall(dest: .accoundId(receiver), value: amount, currencyId: currencyId)
        return RuntimeCall(moduleName: "Tokens", callName: "transfer", args: args)
    }

    private func ormlAssetTransfer(
        to receiver: AccountId,
        amount: BigUInt,
        currencyId: CurrencyId?
    ) -> RuntimeCall<TransferCall> {
        let args = TransferCall(dest: .accoundId(receiver), value: amount, currencyId: currencyId)
        return RuntimeCall(moduleName: "Currencies", callName: "transfer", args: args)
    }

    private func equilibriumAssetTransfer(
        to receiver: AccountId,
        amount: BigUInt,
        currencyId: CurrencyId?
    ) -> RuntimeCall<TransferCall> {
        let args = TransferCall(dest: .accountTo(receiver), value: amount, currencyId: currencyId)
        return RuntimeCall(moduleName: "EqBalances", callName: "transfer", args: args)
    }

    private func defaultTransfer(
        to receiver: AccountId,
        amount: BigUInt
    ) -> RuntimeCall<TransferCall> {
        let args = TransferCall(dest: .accoundId(receiver), value: amount, currencyId: nil)
        return RuntimeCall(moduleName: "Balances", callName: "transfer", args: args)
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
