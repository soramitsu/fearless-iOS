import Foundation
import FearlessUtils

extension RuntimeCall {
    static func bond(_ args: BondCall) -> RuntimeCall<BondCall> {
        RuntimeCall<BondCall>(moduleName: "Staking", callName: "bond", args: args)
    }

    static func nominate(_ args: NominateCall) -> RuntimeCall<NominateCall> {
        RuntimeCall<NominateCall>(moduleName: "Staking", callName: "nominate", args: args)
    }

    static func transfer(_ args: TransferCall) -> RuntimeCall<TransferCall> {
        RuntimeCall<TransferCall>(moduleName: "Balances", callName: "transfer", args: args)
    }

    static func payout(_ args: PayoutCall) -> RuntimeCall<PayoutCall> {
        RuntimeCall<PayoutCall>(moduleName: "Staking", callName: "payout_stakers", args: args)
    }
}
