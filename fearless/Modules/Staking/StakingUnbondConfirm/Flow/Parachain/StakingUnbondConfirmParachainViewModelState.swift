import Foundation
import Web3
import SSFUtils
import SSFModels

final class StakingUnbondConfirmParachainViewModelState: StakingUnbondConfirmViewModelState {
    var stateListener: StakingUnbondConfirmModelStateListener?
    let revoke: Bool
    let candidate: ParachainStakingCandidateInfo
    let delegation: ParachainStakingDelegation
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let dataValidatingFactory: StakingDataValidatingFactory
    let inputAmount: Decimal
    private let callFactory: SubstrateCallFactoryProtocol
    private(set) var bonded: Decimal?
    private(set) var balance: Decimal?
    private(set) var minimalBalance: Decimal?
    private(set) var minNominatorBonded: Decimal?
    private(set) var fee: Decimal?

    var builderClosure: ExtrinsicBuilderClosure? {
        guard
            let amount = inputAmount.toSubstrateAmount(precision: Int16(chainAsset.asset.precision)) else {
            return nil
        }

        return { [unowned self] builder in
            var newBuilder = builder
            if self.revoke {
                let call = self.callFactory.scheduleRevokeDelegation(candidate: self.candidate.owner)
                newBuilder = try newBuilder.adding(call: call)
            } else {
                if self.isCollator {
                    newBuilder = try newBuilder.adding(call: self.callFactory.scheduleCandidateBondLess(amount: amount))
                } else {
                    let call = self.callFactory.scheduleDelegatorBondLess(candidate: candidate.owner, amount: amount)
                    newBuilder = try newBuilder.adding(call: call)
                }
            }

            return newBuilder
        }
    }

    var builderClosureOld: ExtrinsicBuilderClosure? {
        nil
    }

    var reuseIdentifier: String? {
        guard
            let amount = StakingConstants.maxAmount.toSubstrateAmount(
                precision: Int16(chainAsset.asset.precision)
            ) else {
            return nil
        }

        var identifier = ""

        if revoke {
            identifier = callFactory.scheduleRevokeDelegation(candidate: candidate.owner).callName
        } else {
            if isCollator {
                identifier = callFactory.scheduleCandidateBondLess(amount: amount).callName
            } else {
                identifier = callFactory.scheduleDelegatorBondLess(candidate: candidate.owner, amount: amount).callName
            }
        }

        return identifier
    }

    var accountAddress: AccountAddress? {
        wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress()
    }

    private var isCollator: Bool {
        delegation.owner == wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId
    }

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        dataValidatingFactory: StakingDataValidatingFactory,
        inputAmount: Decimal,
        candidate: ParachainStakingCandidateInfo,
        delegation: ParachainStakingDelegation,
        revoke: Bool,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.dataValidatingFactory = dataValidatingFactory
        self.inputAmount = inputAmount
        self.candidate = candidate
        self.delegation = delegation
        self.revoke = revoke

        bonded = Decimal.fromSubstrateAmount(
            delegation.amount,
            precision: Int16(chainAsset.asset.precision)
        )
        self.callFactory = callFactory
    }

    func setStateListener(_ stateListener: StakingUnbondConfirmModelStateListener?) {
        self.stateListener = stateListener
    }

    func validators(using locale: Locale) -> [DataValidating] {
        [
            dataValidatingFactory.canUnbond(amount: inputAmount, bonded: bonded, locale: locale),

            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.stateListener?.refreshFeeIfNeeded()
            }),

            dataValidatingFactory.canPayFee(balance: balance, fee: fee, locale: locale)
        ]
    }
}

extension StakingUnbondConfirmParachainViewModelState: StakingUnbondConfirmParachainStrategyOutput {
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
            if let fee = BigUInt(string: dispatchInfo.fee) {
                self.fee = Decimal.fromSubstrateAmount(fee, precision: Int16(chainAsset.asset.precision))
            }

            stateListener?.provideFeeViewModel()
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

            stateListener?.provideAssetViewModel()
            stateListener?.refreshFeeIfNeeded()
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveMinBonded(result: Result<BigUInt?, Error>) {
        switch result {
        case let .success(minNominatorBonded):
            if let minNominatorBonded = minNominatorBonded {
                self.minNominatorBonded = Decimal.fromSubstrateAmount(
                    minNominatorBonded,
                    precision: Int16(chainAsset.asset.precision)
                )
            } else {
                self.minNominatorBonded = nil
            }

            stateListener?.refreshFeeIfNeeded()
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didSubmitUnbonding(result: Result<String, Error>) {
        stateListener?.didSubmitUnbonding(result: result)
    }
}
