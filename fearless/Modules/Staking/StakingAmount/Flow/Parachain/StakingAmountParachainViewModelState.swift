import Foundation
import BigInt

class StakingAmountParachainViewModelState: StakingAmountViewModelState {
    var amount: Decimal?
    var fee: Decimal?

    var stateListener: StakingAmountModelStateListener?
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let wallet: MetaAccountModel
    let chainAsset: ChainAsset

    init(
        stateListener: StakingAmountModelStateListener?,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) {
        self.stateListener = stateListener
        self.dataValidatingFactory = dataValidatingFactory
        self.wallet = wallet
        self.chainAsset = chainAsset
    }

    var feeExtrinsicBuilderClosure: ExtrinsicBuilderClosure {
        let closure: ExtrinsicBuilderClosure = { builder in
            guard let accountId = Data.random(of: 20) else {
                return builder
            }

            let call = SubstrateCallFactory().delegate(
                candidate: accountId,
                amount: BigUInt(stringLiteral: "9999999999999999"),
                candidateDelegationCount: 100,
                delegationCount: 100
            )

            return try builder.adding(call: call)
        }

        return closure
    }

    var validators: [DataValidating] {
        []
    }

    private func notifyListeners() {
        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func setStateListener(_ stateListener: StakingAmountModelStateListener?) {
        self.stateListener = stateListener
    }

    func updateAmount(_ newValue: Decimal) {
        amount = newValue
    }
}

extension StakingAmountParachainViewModelState: StakingAmountParachainStrategyOutput {
    func didSetup() {
        stateListener?.provideYourRewardDestinationViewModel(viewModelState: self)
    }

    func didReceive(error _: Error) {}

    func didReceive(paymentInfo: RuntimeDispatchInfo) {
        if let feeValue = BigUInt(paymentInfo.fee),
           let fee = Decimal.fromSubstrateAmount(feeValue, precision: Int16(chainAsset.asset.precision)) {
            self.fee = fee
        } else {
            fee = nil
        }

        notifyListeners()
    }
}
