import Foundation
import SSFUtils
import IrohaCrypto
import BigInt
import SSFModels
import SSFRuntimeCodingService

enum SubstrateCallFactoryError: Error {
    case metadataUnavailable
    case callNotFound
}

// swiftlint:disable type_body_length file_length
class SubstrateCallFactoryDefault: SubstrateCallFactoryProtocol {
    private let runtimeService: RuntimeProviderProtocol

    init(runtimeService: RuntimeProviderProtocol) {
        self.runtimeService = runtimeService
    }

    // MARK: - Public methods

    func bond(
        amount: BigUInt,
        controller: String,
        rewardDestination: RewardDestination<String>,
        chainAsset: ChainAsset
    ) throws -> any RuntimeCallable {
        guard let metadata = runtimeService.snapshot?.metadata else {
            throw SubstrateCallFactoryError.metadataUnavailable
        }

        let controllerId = try AddressFactory.accountId(from: controller, chain: chainAsset.chain)

        let controllerIdParam = chainAsset.chain.stakingSettings?.accountIdParam(accountId: controllerId) ?? .accoundId(controllerId)

        let destArg: RewardDestinationArg

        switch rewardDestination {
        case .restake:
            destArg = .staked
        case let .payout(address):
            let accountId = try AddressFactory.accountId(from: address, chain: chainAsset.chain)
            destArg = .account(accountId)
        }
        let path: SubstrateCallPath = .bond

        let callHasControllerArgument = try metadata.modules
            .first(where: { $0.name.lowercased() == path.moduleName.lowercased() })?
            .calls(using: metadata.schemaResolver)?
            .first(where: { $0.name.lowercased() == path.callName.lowercased() })?
            .arguments
            .first(where: { $0.name.lowercased() == "controller" }) != nil

        let maybeControllerIdParam: MultiAddress? = callHasControllerArgument ? controllerIdParam : nil

        let args = BondCall(
            controller: maybeControllerIdParam,
            value: amount,
            payee: destArg
        )

        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func bondExtra(amount: BigUInt) -> any RuntimeCallable {
        let args = BondExtraCall(amount: amount)
        let path: SubstrateCallPath = .bondExtra
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func unbond(amount: BigUInt) -> any RuntimeCallable {
        let args = UnbondCall(amount: amount)
        let path: SubstrateCallPath = .unbond
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func rebond(amount: BigUInt) -> any RuntimeCallable {
        let args = RebondCall(amount: amount)
        let path: SubstrateCallPath = .rebond
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func nominate(targets: [SelectedValidatorInfo], chainAsset: ChainAsset) throws -> any RuntimeCallable {
        let addresses: [MultiAddress] = try targets.map { info in
            let accountId = try AddressFactory.accountId(from: info.address, chain: chainAsset.chain)
            let accountIdParam = chainAsset.chain.stakingSettings?.accountIdParam(accountId: accountId) ?? .accoundId(accountId)
            return accountIdParam
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
    ) throws -> any RuntimeCallable {
        let addresses: [AccountId] = try targets.map { info in
            try info.address.toAccountId()
        }

        let args = PoolNominateCall(pool_id: "\(poolId)", validators: addresses)

        return RuntimeCall(moduleName: "NominationPools", callName: "nominate", args: args)
    }

    func payout(validatorId: Data, era: EraIndex) throws -> any RuntimeCallable {
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
    ) -> any RuntimeCallable {
        switch chainAsset.chainAssetType {
        case .normal, .none:
            if chainAsset.chain.isSora {
                return ormlAssetTransfer(
                    to: receiver,
                    amount: amount,
                    currencyId: chainAsset.currencyId,
                    path: .assetsTransfer
                )
            }
            if chainAsset.chain.isReef {
                return reefTransfer(to: receiver, amount: amount)
            }

            return defaultTransfer(to: receiver, amount: amount)
        case .ormlChain:
            return ormlChainTransfer(
                to: receiver,
                amount: amount,
                currencyId: chainAsset.currencyId
            )
        case
            .ormlAsset,
            .foreignAsset,
            .stableAssetPoolToken,
            .liquidCrowdloan,
            .vToken,
            .vsToken,
            .stable,
            .assetId,
            .token2,
            .xcm:
            return ormlAssetTransfer(
                to: receiver,
                amount: amount,
                currencyId: chainAsset.currencyId,
                path: .ormlAssetTransfer
            )
        case .equilibrium:
            return equilibriumAssetTransfer(
                to: receiver,
                amount: amount,
                currencyId: chainAsset.currencyId
            )
        case .soraAsset:
            return ormlAssetTransfer(
                to: receiver,
                amount: amount,
                currencyId: chainAsset.currencyId,
                path: .assetsTransfer
            )
        case .assets:
            return assetsTransfer(
                to: receiver,
                amount: amount,
                currencyId: chainAsset.currencyId,
                isEthereumBased: chainAsset.chain.isEthereumBased
            )
        }
    }

    func transfer(to receiver: AccountId, amount: BigUInt) -> any RuntimeCallable {
        let args = TransferCall(dest: .accoundId(receiver), value: amount, currencyId: nil)
        let path: SubstrateCallPath = .transfer
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func xorlessTransfer(_ transfer: XorlessTransfer) -> any RuntimeCallable {
        let path: SubstrateCallPath = .xorlessTransfer
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: transfer
        )
    }

    func setPayee(for destination: RewardDestinationArg) -> any RuntimeCallable {
        let args = SetPayeeCall(payee: destination)
        let path: SubstrateCallPath = .setPayee
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func withdrawUnbonded(for numberOfSlashingSpans: UInt32) -> any RuntimeCallable {
        let args = WithdrawUnbondedCall(numberOfSlashingSpans: numberOfSlashingSpans)
        let path: SubstrateCallPath = .withdrawUnbonded
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func setController(_ controller: AccountAddress, chainAsset: ChainAsset) throws -> any RuntimeCallable {
        guard let metadata = runtimeService.snapshot?.metadata else {
            return try defaultSetController(controller, chainAsset: chainAsset)
        }

        let callHasArguments = try metadata.modules
            .first(where: { $0.name.lowercased() == SubstrateCallPath.setController.moduleName.lowercased() })?
            .calls(using: metadata.schemaResolver)?
            .first(where: { $0.name.lowercased() == SubstrateCallPath.setController.callName.lowercased() })?
            .arguments.isNotEmpty == true

        let controllerId = try AddressFactory.accountId(from: controller, chain: chainAsset.chain)
        let accountIdParam = chainAsset.chain.stakingSettings?.accountIdParam(accountId: controllerId) ?? .accoundId(controllerId)

        let path: SubstrateCallPath = .setController

        let args: SetControllerCall? = callHasArguments ? SetControllerCall(controller: accountIdParam) : nil

        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    private func defaultSetController(_ controller: AccountAddress, chainAsset: ChainAsset) throws -> any RuntimeCallable {
        let controllerId = try AddressFactory.accountId(from: controller, chain: chainAsset.chain)
        let accountIdParam = chainAsset.chain.stakingSettings?.accountIdParam(accountId: controllerId) ?? .accoundId(controllerId)

        let args = SetControllerCall(controller: accountIdParam)
        let path: SubstrateCallPath = .setController
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func chill() -> any RuntimeCallable {
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
    ) -> any RuntimeCallable {
        let args = CrowdloanContributeCall(index: paraId, value: amount, signature: multiSignature)
        let path: SubstrateCallPath = .contribute
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func addMemo(to paraId: ParaId, memo: Data) -> any RuntimeCallable {
        let args = CrowdloanAddMemo(index: paraId, memo: memo)
        let path: SubstrateCallPath = .addMemo
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func addRemark(_ data: Data) -> any RuntimeCallable {
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
    ) -> any RuntimeCallable {
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
    ) -> any RuntimeCallable {
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
    ) -> any RuntimeCallable {
        let args = ScheduleDelegatorBondLessCall(candidate: candidate, less: amount)

        let path: SubstrateCallPath = .scheduleDelegatorBondLess
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func scheduleRevokeDelegation(candidate: AccountId) -> any RuntimeCallable {
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
    ) -> any RuntimeCallable {
        let args = ExecuteDelegationRequestCall(delegator: delegator, candidate: collator)

        let path: SubstrateCallPath = .executeDelegationRequest
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func cancelCandidateBondLess() -> any RuntimeCallable {
        let path: SubstrateCallPath = .cancelCandidateBondLess
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName
        )
    }

    func cancelDelegationRequest(candidate: AccountId) -> any RuntimeCallable {
        let args = CancelDelegationRequestCall(candidate: candidate)

        let path: SubstrateCallPath = .cancelDelegationRequest
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func cancelLeaveDelegators() -> any RuntimeCallable {
        let path: SubstrateCallPath = .cancelLeaveDelegators
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName
        )
    }

    func candidateBondMore(amount: BigUInt) -> any RuntimeCallable {
        let args = CandidateBondMoreCall(more: amount)
        let path: SubstrateCallPath = .candidateBondMore
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func scheduleCandidateBondLess(amount: BigUInt) -> any RuntimeCallable {
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
    ) -> any RuntimeCallable {
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
        bouncer: MultiAddress
    ) throws -> any RuntimeCallable {
        guard let metadata = runtimeService.snapshot?.metadata else {
            throw SubstrateCallFactoryError.metadataUnavailable
        }

        let path: CallCodingPath = .createNominationPool

        let isUpdatedArguments = try? metadata.modules
            .first(where: { $0.name.lowercased() == path.moduleName.lowercased() })?
            .calls(using: metadata.schemaResolver)?
            .first(where: { $0.name.lowercased() == path.callName.lowercased() })?
            .arguments
            .first(where: { $0.name.lowercased() == "bouncer" }) != nil

        let stateTogglerValue: StateTogglerValue = isUpdatedArguments.or(true) ? .bouncer(value: bouncer) : .stateToggler(value: bouncer)

        let args = CreatePoolCall(
            amount: amount,
            root: root,
            nominator: nominator,
            stateToggler: stateTogglerValue
        )

        return RuntimeCall(
            callCodingPath: path,
            args: args
        )
    }

    func setPoolMetadata(
        poolId: String,
        metadata: Data
    ) -> any RuntimeCallable {
        let args = SetMetadataCall(
            poolId: poolId,
            metadata: metadata
        )

        return RuntimeCall(
            callCodingPath: .setPoolMetadata,
            args: args
        )
    }

    func poolBondMore(amount: BigUInt) -> any RuntimeCallable {
        let args = PoolBondMoreCall(
            extra: .freeBalance(amount: amount)
        )

        return RuntimeCall(
            callCodingPath: .poolBondMore,
            args: args
        )
    }

    func poolUnbond(accountId: AccountId, amount: BigUInt) -> any RuntimeCallable {
        let args = PoolUnbondCall(
            memberAccount: .accoundId(accountId),
            unbondingPoints: amount
        )

        return RuntimeCall(
            callCodingPath: .poolUnbond,
            args: args
        )
    }

    func poolUnbondOld(accountId: AccountId, amount: BigUInt) -> any RuntimeCallable {
        let args = PoolUnbondCallOld(
            memberAccount: accountId,
            unbondingPoints: amount
        )

        return RuntimeCall(
            callCodingPath: .poolUnbond,
            args: args
        )
    }

    func poolWithdrawUnbonded(accountId: AccountId, numSlashingSpans: UInt32) -> any RuntimeCallable {
        let args = PoolWithdrawUnbondedCall(
            memberAccount: .accoundId(accountId),
            numSlashingSpans: numSlashingSpans
        )

        return RuntimeCall(
            callCodingPath: .poolWithdrawUnbonded,
            args: args
        )
    }

    func claimPoolRewards() -> any RuntimeCallable {
        RuntimeCall(
            moduleName: CallCodingPath.claimPendingRewards.moduleName,
            callName: CallCodingPath.claimPendingRewards.callName
        )
    }

    func nominationPoolUpdateRoles(
        poolId: String,
        roles: StakingPoolRoles
    ) -> any RuntimeCallable {
        var rootRoleUpdate: UpdateRoleCase
        var nominatorRoleUpdate: UpdateRoleCase
        var bouncerRoleUpdate: UpdateRoleCase

        if let rootAccountId = roles.root {
            rootRoleUpdate = .set(rootAccountId)
        } else {
            rootRoleUpdate = .remove
        }

        if let nominatorAccountId = roles.nominator {
            nominatorRoleUpdate = .set(nominatorAccountId)
        } else {
            nominatorRoleUpdate = .remove
        }

        if let bouncerAccountId = roles.bouncer {
            bouncerRoleUpdate = .set(bouncerAccountId)
        } else {
            bouncerRoleUpdate = .remove
        }

        let args = NominationPoolsUpdateRolesCall(
            poolId: poolId,
            newRoot: rootRoleUpdate,
            newNominator: nominatorRoleUpdate,
            newBouncer: bouncerRoleUpdate
        )

        return RuntimeCall(callCodingPath: .nominationPoolUpdateRoles, args: args)
    }

    // MARK: - Polkaswap

    func swap(
        dexId: String,
        from asset: String,
        to targetAsset: String,
        amountCall: [SwapVariant: SwapAmount],
        type: [[String?]],
        filter: Int
    ) -> any RuntimeCallable {
        let filterMode = PolkaswapLiquidityFilterMode(rawValue: filter) ?? .disabled
        let args = SwapCall(
            dexId: dexId,
            inputAssetId: SoraAssetId(wrappedValue: asset),
            outputAssetId: SoraAssetId(wrappedValue: targetAsset),
            amount: amountCall,
            liquiditySourceType: type,
            filterMode: PolkaswapCallFilterModeType(
                wrappedName: filterMode.code,
                wrappedValue: UInt(filter)
            )
        )

        return RuntimeCall(
            callCodingPath: .polkaswapSwap,
            args: args
        )
    }

    // MARK: - Private methods

    private func ormlChainTransfer(
        to receiver: AccountId,
        amount: BigUInt,
        currencyId: SSFModels.CurrencyId?
    ) -> any RuntimeCallable {
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
        currencyId: SSFModels.CurrencyId?,
        path: SubstrateCallPath
    ) -> any RuntimeCallable {
        let args = TransferCall(dest: .accoundId(receiver), value: amount, currencyId: currencyId)
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    private func equilibriumAssetTransfer(
        to receiver: AccountId,
        amount: BigUInt,
        currencyId: SSFModels.CurrencyId?
    ) -> any RuntimeCallable {
        let args = TransferCall(dest: .accountTo(receiver), value: amount, currencyId: currencyId)
        let path: SubstrateCallPath = .equilibriumAssetTransfer
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    private func assetsTransfer(
        to receiver: AccountId,
        amount: BigUInt,
        currencyId: SSFModels.CurrencyId?,
        isEthereumBased: Bool
    ) -> any RuntimeCallable {
        let dest: MultiAddress = isEthereumBased ? .accountTo(receiver) : .accoundId(receiver)
        let args = TransferCall(dest: dest, value: amount, currencyId: currencyId)
        let path: SubstrateCallPath = .assetsTransfer
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func reefTransfer(
        to receiver: AccountId,
        amount: BigUInt
    ) -> any RuntimeCallable {
        let args = TransferCall(dest: .indexedString(receiver), value: amount, currencyId: nil)
        let path: SubstrateCallPath = .defaultTransfer
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    func defaultTransfer(
        to receiver: AccountId,
        amount: BigUInt
    ) -> any RuntimeCallable {
        guard let metadata = runtimeService.snapshot?.metadata else {
            let args = TransferCall(dest: .accoundId(receiver), value: amount, currencyId: nil)
            let path: SubstrateCallPath = .defaultTransfer
            return RuntimeCall(
                moduleName: path.moduleName,
                callName: path.callName,
                args: args
            )
        }

        let transferAllowDeathAvailable = try? metadata.modules
            .first(where: { $0.name.lowercased() == SubstrateCallPath.transferAllowDeath.moduleName.lowercased() })?
            .calls(using: metadata.schemaResolver)?
            .first(where: { $0.name.lowercased() == SubstrateCallPath.transferAllowDeath.callName.lowercased() }) != nil

        let path: SubstrateCallPath = transferAllowDeathAvailable == true ? .transferAllowDeath : .defaultTransfer

        let args = TransferCall(dest: .accoundId(receiver), value: amount, currencyId: nil)
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }
}

// MARK: - extension SubstrateCallFactory

extension SubstrateCallFactoryDefault {
    func setRewardDestination(
        _ rewardDestination: RewardDestination<AccountAddress>,
        stashItem: StashItem,
        chainAsset: ChainAsset
    ) throws -> any RuntimeCallable {
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

                let accountId = try AddressFactory.accountId(from: accountAddress, chain: chainAsset.chain)

                guard let chainStakingSettings = chainAsset.chain.stakingSettings else {
                    return .account(accountId)
                }

                return chainStakingSettings.rewardDestinationArg(accountId: accountId)
            }
        }()

        return setPayee(for: arg)
    }

    func vestingClaim() throws -> any RuntimeCallable {
        guard let metadata = runtimeService.snapshot?.metadata else {
            throw SubstrateCallFactoryError.metadataUnavailable
        }
        let vestingClaimPath: SubstrateCallPath = .vestingClaim
        let vestingVestPath: SubstrateCallPath = .vestingVest
        let vestedRewardsClaimRewardsPath: SubstrateCallPath = .vestedRewardsClaimRewards

        let vestingClaimCallExists = try metadata.modules
            .first(where: { $0.name.lowercased() == vestingClaimPath.moduleName.lowercased() })?
            .calls(using: metadata.schemaResolver)?
            .first(where: { $0.name.lowercased() == vestingClaimPath.callName.lowercased() }) != nil

        let vestingVestCallExists = try metadata.modules
            .first(where: { $0.name.lowercased() == vestingVestPath.moduleName.lowercased() })?
            .calls(using: metadata.schemaResolver)?
            .first(where: { $0.name.lowercased() == vestingVestPath.callName.lowercased() }) != nil

        let vestedRewardsClaimRewardsExists = try metadata.modules
            .first(where: { $0.name.lowercased() == vestedRewardsClaimRewardsPath.moduleName.lowercased() })?
            .calls(using: metadata.schemaResolver)?
            .first(where: { $0.name.lowercased() == vestedRewardsClaimRewardsPath.callName.lowercased() }) != nil

        if vestingVestCallExists {
            let path: SubstrateCallPath = vestingVestPath
            return RuntimeCall(
                moduleName: path.moduleName,
                callName: path.callName
            )
        }

        if vestingClaimCallExists {
            let path: SubstrateCallPath = vestingClaimPath
            return RuntimeCall(
                moduleName: path.moduleName,
                callName: path.callName
            )
        }

        if vestedRewardsClaimRewardsExists {
            let path: SubstrateCallPath = vestedRewardsClaimRewardsPath
            return RuntimeCall(
                moduleName: path.moduleName,
                callName: path.callName
            )
        }

        throw SubstrateCallFactoryError.callNotFound
    }
}
