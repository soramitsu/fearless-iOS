import Foundation
import BigInt

final class SelectValidatorsConfirmParachainViewModelState: SelectValidatorsConfirmViewModelState {
    let target: ParachainStakingCandidateInfo
    let maxTargets: Int
    let initiatedBonding: InitiatedBonding
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    var stateListener: SelectValidatorsConfirmModelStateListener?

    var confirmationModel: SelectValidatorsConfirmParachainModel?

    private(set) var balance: Decimal?
    private(set) var priceData: PriceData?
    private(set) var fee: Decimal?
    private(set) var minimalBalance: Decimal?
    private(set) var networkStakingInfo: NetworkStakingInfo?

    private(set) var candidateDelegationCount: UInt32?
    private(set) var delegationCount: UInt32?

    func setStateListener(_ stateListener: SelectValidatorsConfirmModelStateListener?) {
        self.stateListener = stateListener
    }

    init(
        target: ParachainStakingCandidateInfo,
        maxTargets: Int,
        initiatedBonding: InitiatedBonding,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        self.target = target
        self.maxTargets = maxTargets
        self.initiatedBonding = initiatedBonding
        self.chainAsset = chainAsset
        self.wallet = wallet
    }

    func createExtrinsicBuilderClosure() -> ExtrinsicBuilderClosure? {
        guard let amount = initiatedBonding.amount
            .toSubstrateAmount(precision: Int16(chainAsset.asset.precision))
        else {
            return nil
        }

        let closure: ExtrinsicBuilderClosure = { [weak self] builder in
            guard let strongSelf = self,
                  let candidateDelegationCount = self?.candidateDelegationCount,
                  let delegationCount = self?.delegationCount else {
                return builder
            }

            let call = SubstrateCallFactory().delegate(
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
            return
        }

        delegationCount = UInt32(state.delegations.count)

        stateListener?.feeParametersUpdated()
    }

    func didSetup() {
        provideInitiatedBondingConfirmationModel()
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            if let availableValue = accountInfo?.data.available {
                balance = Decimal.fromSubstrateAmount(
                    availableValue,
                    precision: Int16(chainAsset.asset.precision)
                )
            } else {
                balance = 0.0
            }

            stateListener?.provideAsset(viewModelState: self)
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
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
        if let feeValue = BigUInt(paymentInfo.fee),
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
}
