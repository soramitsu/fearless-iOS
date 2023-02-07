import Foundation
import BigInt

final class StakingUnbondSetupParachainViewModelState: StakingUnbondSetupViewModelState {
    var stateListener: StakingUnbondSetupModelStateListener?
    let delegation: ParachainStakingDelegation
    let candidate: ParachainStakingCandidateInfo
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    private let dataValidatingFactory: StakingDataValidatingFactory
    private let callFactory: SubstrateCallFactoryProtocol = SubstrateCallFactory()
    private(set) var bonded: Decimal?
    private(set) var balance: Decimal?
    private(set) var inputAmount: Decimal?
    private(set) var bondingDuration: UInt32?
    private(set) var minimalBalance: Decimal?
    private(set) var fee: Decimal?
    private(set) var controller: ChainAccountResponse?
    private var topDelegations: ParachainStakingDelegations?

    var builderClosure: ExtrinsicBuilderClosure? {
        guard
            let amount = StakingConstants.maxAmount.toSubstrateAmount(
                precision: Int16(chainAsset.asset.precision)
            ) else {
            return nil
        }

        return { [unowned self] builder in
            var newBuilder = builder
            if self.isRevoke {
                newBuilder = try newBuilder.adding(call: self.callFactory.scheduleRevokeDelegation(candidate: self.candidate.owner))
            } else {
                if self.isCollator {
                    newBuilder = try newBuilder.adding(call: self.callFactory.scheduleCandidateBondLess(amount: amount))
                } else {
                    newBuilder = try newBuilder.adding(call: self.callFactory.scheduleDelegatorBondLess(amount: amount))
                }
            }

            return newBuilder
        }
    }

    var reuseIdentifier: String? {
        guard
            let amount = StakingConstants.maxAmount.toSubstrateAmount(
                precision: Int16(chainAsset.asset.precision)
            ) else {
            return nil
        }

        var identifier = ""

        if isRevoke {
            identifier = callFactory.scheduleRevokeDelegation(candidate: candidate.owner).callName
        } else {
            if isCollator {
                identifier = callFactory.scheduleCandidateBondLess(amount: amount).callName
            } else {
                identifier = callFactory.scheduleDelegatorBondLess(amount: amount).callName
            }
        }

        return identifier
    }

    var confirmationFlow: StakingUnbondConfirmFlow? {
        guard let inputAmount = amount else {
            return nil
        }

        return .parachain(
            candidate: candidate,
            delegation: delegation,
            amount: inputAmount,
            revoke: isRevoke,
            bondingDuration: bondingDuration
        )
    }

    var accountAddress: AccountAddress? {
        wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress()
    }

    var amount: Decimal? {
        isRevoke ? bonded : inputAmount
    }

    var minimumDelegation: Decimal? {
        guard let minDelegationSubstrateValue = topDelegations?.delegations.map(\.amount).min(),
              let minDelegationDecimal = Decimal.fromSubstrateAmount(
                  minDelegationSubstrateValue,
                  precision: Int16(chainAsset.asset.precision)
              ) else {
            return nil
        }

        return minDelegationDecimal
    }

    var isRevoke: Bool {
        if let amount = inputAmount, let bonded = bonded, let minimumAmount = minimumDelegation {
            return bonded - amount < minimumAmount || bonded == amount
        }

        return false
    }

    private var isCollator: Bool {
        delegation.owner == wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId
    }

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        dataValidatingFactory: StakingDataValidatingFactory,
        candidate: ParachainStakingCandidateInfo,
        delegation: ParachainStakingDelegation
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.dataValidatingFactory = dataValidatingFactory
        self.candidate = candidate
        self.delegation = delegation

        bonded = Decimal.fromSubstrateAmount(
            delegation.amount,
            precision: Int16(chainAsset.asset.precision)
        )
    }

    func setStateListener(_ stateListener: StakingUnbondSetupModelStateListener?) {
        self.stateListener = stateListener
    }

    func validators(using locale: Locale) -> [DataValidating] {
        [
            dataValidatingFactory.canUnbond(amount: inputAmount, bonded: bonded, locale: locale),

            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.stateListener?.updateFeeIfNeeded()
            }),

            dataValidatingFactory.canPayFee(balance: balance, fee: fee, locale: locale),

            dataValidatingFactory.stashIsNotKilledAfterUnbonding(
                amount: inputAmount,
                bonded: bonded,
                minimumAmount: minimumDelegation,
                locale: locale
            )
        ]
    }

    func selectAmountPercentage(_ percentage: Float) {
        if let bonded = bonded {
            inputAmount = bonded * Decimal(Double(percentage))
            stateListener?.provideInputViewModel()
            stateListener?.provideAssetViewModel()
        }
    }

    func updateAmount(_ amount: Decimal) {
        inputAmount = amount
        stateListener?.provideAssetViewModel()

        if fee == nil {
            stateListener?.updateFeeIfNeeded()
        }
    }
}

extension StakingUnbondSetupParachainViewModelState: StakingUnbondSetupParachainStrategyOutput {
    func didReceiveTopDelegations(delegations: [AccountAddress: ParachainStakingDelegations]) {
        topDelegations = delegations[candidate.address]
    }

    func didSetup() {
        stateListener?.provideAccountViewModel()
        stateListener?.provideCollatorViewModel()
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            if let accountInfo = accountInfo {
                balance = Decimal.fromSubstrateAmount(
                    accountInfo.data.stakingAvailable,
                    precision: Int16(chainAsset.asset.precision)
                )
            } else {
                balance = nil
            }
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            if let fee = BigUInt(dispatchInfo.fee) {
                self.fee = Decimal.fromSubstrateAmount(fee, precision: Int16(chainAsset.asset.precision))
            }

            stateListener?.provideFeeViewModel()
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveBondingDuration(result: Result<UInt32, Error>) {
        switch result {
        case let .success(bondingDuration):
            self.bondingDuration = bondingDuration
            stateListener?.provideBondingDuration()
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(minimalBalance):
            self.minimalBalance = Decimal.fromSubstrateAmount(
                minimalBalance,
                precision: Int16(chainAsset.asset.precision)
            )
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }
}
