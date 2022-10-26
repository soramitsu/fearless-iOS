import Foundation

enum SubstrateCallPath: CaseIterable {
    var moduleName: String {
        path.moduleName
    }

    var callName: String {
        path.callName
    }

    var path: (moduleName: String, callName: String) {
        switch self {
        case .bond:
            return (moduleName: "Staking", callName: "bond")
        case .bondExtra:
            return (moduleName: "Staking", callName: "bond_extra")
        case .unbond:
            return (moduleName: "Staking", callName: "unbond")
        case .rebond:
            return (moduleName: "Staking", callName: "rebond")
        case .nominate:
            return (moduleName: "Staking", callName: "nominate")
        case .payout:
            return (moduleName: "Staking", callName: "payout_stakers")
        case .transfer:
            return (moduleName: "Balances", callName: "transfer")
        case .setPayee:
            return (moduleName: "Staking", callName: "set_payee")
        case .withdrawUnbonded:
            return (moduleName: "Staking", callName: "withdraw_unbonded")
        case .setController:
            return (moduleName: "Staking", callName: "set_controller")
        case .chill:
            return (moduleName: "Staking", callName: "chill")
        case .contribute:
            return (moduleName: "Crowdloan", callName: "contribute")
        case .addMemo:
            return (moduleName: "Crowdloan", callName: "add_memo")
        case .addRemark:
            return (moduleName: "System", callName: "remark")
        case .delegate:
            return (moduleName: "ParachainStaking", callName: "delegate_with_auto_compound")
        case .delegatorBondMore:
            return (moduleName: "ParachainStaking", callName: "delegator_bond_more")
        case .scheduleDelegatorBondLess:
            return (moduleName: "ParachainStaking", callName: "schedule_delegator_bond_less")
        case .scheduleRevokeDelegation:
            return (moduleName: "ParachainStaking", callName: "schedule_revoke_delegation")
        case .executeDelegationRequest:
            return (moduleName: "ParachainStaking", callName: "execute_delegation_request")
        case .cancelCandidateBondLess:
            return (moduleName: "ParachainStaking", callName: "cancel_candidate_bond_less")
        case .cancelDelegationRequest:
            return (moduleName: "ParachainStaking", callName: "cancel_delegation_request")
        case .cancelLeaveDelegators:
            return (moduleName: "ParachainStaking", callName: "cancel_leave_delegators")
        case .candidateBondMore:
            return (moduleName: "ParachainStaking", callName: "candidate_bond_more")
        case .scheduleCandidateBondLess:
            return (moduleName: "ParachainStaking", callName: "schedule_candidate_bond_less")
        case .ormlChainTransfer:
            return (moduleName: "Tokens", callName: "transfer")
        case .ormlAssetTransfer:
            return (moduleName: "Currencies", callName: "transfer")
        case .equilibriumAssetTransfer:
            return (moduleName: "EqBalances", callName: "transfer")
        case .defaultTransfer:
            return (moduleName: "Balances", callName: "transfer")
        }
    }

    case bond
    case bondExtra
    case unbond
    case rebond
    case nominate
    case payout
    case transfer
    case setPayee
    case withdrawUnbonded
    case setController
    case chill
    case contribute
    case addMemo
    case addRemark
    case delegate
    case delegatorBondMore
    case scheduleDelegatorBondLess
    case scheduleRevokeDelegation
    case executeDelegationRequest
    case cancelCandidateBondLess
    case cancelDelegationRequest
    case cancelLeaveDelegators
    case candidateBondMore
    case scheduleCandidateBondLess
    case ormlChainTransfer
    case ormlAssetTransfer
    case equilibriumAssetTransfer
    case defaultTransfer
}
