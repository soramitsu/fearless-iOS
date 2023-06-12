import Foundation
import Web3
import SSFModels

final class SelectValidatorsConfirmParachainViewModelState: SelectValidatorsConfirmViewModelState {
    var balance: Decimal?
    let target: ParachainStakingCandidateInfo
    let maxTargets: Int
    let initiatedBonding: InitiatedBonding
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    var stateListener: SelectValidatorsConfirmModelStateListener?
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    private let callFactory: SubstrateCallFactoryProtocol

    private(set) var confirmationModel: SelectValidatorsConfirmParachainModel?
    private(set) var priceData: PriceData?
    private(set) var fee: Decimal?
    private(set) var minimalBalance: Decimal?
    private(set) var networkStakingInfo: NetworkStakingInfo?
    private(set) var amount: Decimal?
    private(set) var candidateDelegationCount: UInt32?
    private(set) var delegationCount: UInt32?

    var walletAccountAddress: String? {
        wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress()
    }

    var collatorAddress: String? {
        target.address
    }

    init(
        target: ParachainStakingCandidateInfo,
        maxTargets: Int,
        initiatedBonding: InitiatedBonding,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.target = target
        self.maxTargets = maxTargets
        self.initiatedBonding = initiatedBonding
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.dataValidatingFactory = dataValidatingFactory
        self.callFactory = callFactory
    }

    func setStateListener(_ stateListener: SelectValidatorsConfirmModelStateListener?) {
        self.stateListener = stateListener
    }

    func validators(using locale: Locale) -> [DataValidating] {
        let minimumStake = Decimal.fromSubstrateAmount(
            networkStakingInfo?.baseInfo.minStakeAmongActiveNominators ?? BigUInt.zero,
            precision: Int16(chainAsset.asset.precision)
        ) ?? 0

        return [
            dataValidatingFactory.canNominate(
                amount: initiatedBonding.amount,
                minimalBalance: minimalBalance,
                minNominatorBond: minimumStake,
                locale: locale
            ),
            dataValidatingFactory.bondAtLeastMinStaking(
                asset: chainAsset.asset,
                amount: initiatedBonding.amount,
                minNominatorBond: minimumStake,
                locale: locale
            ),
            dataValidatingFactory.canPayFeeAndAmount(
                balance: balance,
                fee: fee,
                spendingAmount: amount,
                locale: locale
            )
        ]
    }

    func createExtrinsicBuilderClosure() -> ExtrinsicBuilderClosure? {
        guard let amount = initiatedBonding.amount
            .toSubstrateAmount(precision: Int16(chainAsset.asset.precision))
        else {
            return nil
        }

        let closure: ExtrinsicBuilderClosure = { [weak self] builder in
            guard let strongSelf = self,
                  let candidateDelegationCount = self?.target.metadata?.delegationCount,
                  let delegationCount = self?.delegationCount else {
                return builder
            }

            let call = strongSelf.callFactory.delegate(
                candidate: strongSelf.target.owner,
                amount: amount,
                candidateDelegationCount: candidateDelegationCount,
                delegationCount: delegationCount
            )

            return try builder.adding(call: call)
        }

        return closure
    }

    private func provideInitiatedBondingConfirmationModel() {
        let stash = DisplayAddress(
            address: wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() ?? "",
            username: wallet.name
        )

        confirmationModel = SelectValidatorsConfirmParachainModel(
            wallet: stash,
            amount: initiatedBonding.amount,
            target: target,
            maxTargets: maxTargets
        )

        stateListener?.provideConfirmationState(viewModelState: self)
    }
}

extension SelectValidatorsConfirmParachainViewModelState: SelectValidatorsConfirmParachainStrategyOutput {
    func didReceiveAtStake(snapshot: ParachainStakingCollatorSnapshot?) {
        guard let snapshot = snapshot else {
            return
        }

        candidateDelegationCount = UInt32(snapshot.delegations.count)

        stateListener?.feeParametersUpdated()
    }

    func didReceiveDelegatorState(state: ParachainStakingDelegatorState?) {
        guard let state = state else {
            delegationCount = 0
            return
        }

        delegationCount = UInt32(state.delegations.count)

        stateListener?.feeParametersUpdated()
    }

    func didSetup() {
        provideInitiatedBondingConfirmationModel()
    }

    func didStartNomination() {
        stateListener?.didStartNomination()
    }

    func didCompleteNomination(txHash: String) {
        stateListener?.didCompleteNomination(txHash: txHash)
    }

    func didFailNomination(error: Error) {
        stateListener?.didFailNomination(error: error)
    }

    func didReceive(paymentInfo: RuntimeDispatchInfo) {
        if let feeValue = BigUInt(string: paymentInfo.fee),
           let fee = Decimal.fromSubstrateAmount(feeValue, precision: Int16(chainAsset.asset.precision)) {
            self.fee = fee
        } else {
            fee = nil
        }

        stateListener?.provideFee(viewModelState: self)
    }

    func didReceiveFeeError(_ feeError: Error) {
        stateListener?.didReceiveError(error: feeError)
    }

    func didReceive(error: Error) {
        stateListener?.didReceiveError(error: error)
    }

    func didReceiveNetworkStakingInfo(info: NetworkStakingInfo) {
        networkStakingInfo = info

        stateListener?.provideHints(viewModelState: self)
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            if let availableValue = accountInfo?.data.stakingAvailable {
                balance = Decimal.fromSubstrateAmount(
                    availableValue,
                    precision: Int16(chainAsset.asset.precision)
                )
            } else {
                balance = 0.0
            }
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }
}
