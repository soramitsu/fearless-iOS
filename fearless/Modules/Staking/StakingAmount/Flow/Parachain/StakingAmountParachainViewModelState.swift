import Foundation

class StakingAmountParachainViewModelState: StakingAmountViewModelState {
    var stateListener: StakingAmountModelStateListener?
    var amount: Decimal?

    var feeExtrinsicBuilderClosure: ExtrinsicBuilderClosure {
        let closure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()

            return try builder
                .adding(call: callFactory.candidatePool())
                .adding(call: callFactory.selectedCandidates())
        }

        return closure
    }

    var validators: [DataValidating] {
        []
    }
}
