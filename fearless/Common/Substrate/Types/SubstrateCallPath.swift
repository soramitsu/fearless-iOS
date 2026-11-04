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
        case .xorlessTransfer:
            return (moduleName: "LiquidityProxy", callName: "xorless_transfer")
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
        case .ormlChainTransfer:
            return (moduleName: "Tokens", callName: "transfer")
        case .ormlAssetTransfer:
            return (moduleName: "Currencies", callName: "transfer")
        case .equilibriumAssetTransfer:
            return (moduleName: "EqBalances", callName: "transfer")
        case .defaultTransfer:
            return (moduleName: "Balances", callName: "transfer")
        case .assetsTransfer:
            return (moduleName: "Assets", callName: "transfer")
        case .transferAllowDeath:
            return (moduleName: "Balances", callName: "transfer_allow_death")
        case .vestingClaim:
            return (moduleName: "Vesting", callName: "claim")
        case .vestingVest:
            return (moduleName: "Vesting", callName: "vest")
        case .vestedRewardsClaimRewards:
            return (moduleName: "VestedRewards", callName: "claim_rewards")
        }
    }

    case bond
    case bondExtra
    case unbond
    case rebond
    case nominate
    case payout
    case transfer
    case xorlessTransfer
    case setPayee
    case withdrawUnbonded
    case setController
    case chill
    case contribute
    case addMemo
    case addRemark
    case ormlChainTransfer
    case ormlAssetTransfer
    case equilibriumAssetTransfer
    case defaultTransfer
    case assetsTransfer
    case transferAllowDeath
    case vestingClaim
    case vestingVest
    case vestedRewardsClaimRewards
}
