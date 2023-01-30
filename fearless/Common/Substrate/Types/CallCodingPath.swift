import Foundation

enum CallCodingPath: Equatable, Codable, CaseIterable {
    static var allCases: [CallCodingPath] {
        [
            .transfer,
            .transferKeepAlive,
            .addMemo,
            .nominationPoolJoin,
            .createNominationPool,
            .setPoolMetadata,
            .poolBondMore,
            .poolUnbond,
            .claimPendingRewards,
            .poolWithdrawUnbonded,
            .nominationPoolUpdateRoles
        ]
    }

    var isTransfer: Bool {
        [.transfer, .transferKeepAlive].contains(self)
    }

    var moduleName: String {
        path.moduleName
    }

    var callName: String {
        path.callName
    }

    var path: (moduleName: String, callName: String) {
        switch self {
        case .transfer:
            return (moduleName: "Balances", callName: "transfer")
        case .transferKeepAlive:
            return (moduleName: "Balances", callName: "transfer_keep_alive")
        case .addMemo:
            return (moduleName: "Crowdloan", callName: "add_memo")
        case .nominationPoolJoin:
            return (moduleName: "NominationPools", callName: "join")
        case .createNominationPool:
            return (moduleName: "NominationPools", callName: "create")
        case .setPoolMetadata:
            return (moduleName: "NominationPools", callName: "set_metadata")
        case .poolBondMore:
            return (moduleName: "NominationPools", callName: "bond_extra")
        case .poolUnbond:
            return (moduleName: "NominationPools", callName: "unbond")
        case .claimPendingRewards:
            return (moduleName: "NominationPools", callName: "claim_payout")
        case .poolWithdrawUnbonded:
            return (moduleName: "NominationPools", callName: "withdraw_unbonded")
        case .nominationPoolUpdateRoles:
            return (moduleName: "NominationPools", callName: "update_roles")
        case let .fromInit(moduleName, callName):
            return (moduleName: moduleName, callName: callName)
        case .polkaswapSwap:
            return (moduleName: "LiquidityProxy", callName: "swap")
        }
    }

    init(moduleName: String, callName: String) {
        self = .fromInit(moduleName: moduleName, callName: callName)
    }

    case fromInit(moduleName: String, callName: String)

    case transfer
    case transferKeepAlive
    case addMemo
    case nominationPoolJoin
    case createNominationPool
    case setPoolMetadata
    case poolBondMore
    case poolUnbond
    case claimPendingRewards
    case poolWithdrawUnbonded
    case nominationPoolUpdateRoles
    case polkaswapSwap
}
