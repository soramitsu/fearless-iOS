import Foundation

struct KmmCallCodingPath: Equatable, Codable {
    let moduleName: String
    let callName: String
}

extension KmmCallCodingPath {
    static var transfer: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "assets", callName: "transfer")
    }

    static var transferKeepAlive: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "assets", callName: "transferKeepAlive")
    }

    static var swap: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "liquidityProxy", callName: "swap")
    }

    static var migration: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "irohaMigration", callName: "migrate")
    }

    static var depositLiquidity: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "poolXYK", callName: "depositLiquidity")
    }

    static var withdrawLiquidity: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "poolXYK", callName: "withdrawLiquidity")
    }

    static var setReferral: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "referrals", callName: "setReferrer")
    }

    static var bondReferralBalance: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "referrals", callName: "reserve")
    }

    static var unbondReferralBalance: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "referrals", callName: "unreserve")
    }

    static var batchUtility: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "utility", callName: "batch")
    }

    static var batchAllUtility: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "utility", callName: "batchAll")
    }

    var isTransfer: Bool {
        [.transfer, .transferKeepAlive].contains(self)
    }

    var isSwap: Bool {
        [.swap].contains(self)
    }

    var isMigration: Bool {
        [.migration].contains(self)
    }

    var isDepositLiquidity: Bool {
        [.depositLiquidity].contains(self)
    }

    var isWithdrawLiquidity: Bool {
        [.withdrawLiquidity].contains(self)
    }

    var isReferral: Bool {
        [.setReferral, .bondReferralBalance, .unbondReferralBalance].contains(self)
    }
}
