import Foundation

struct CallCodingPath: Equatable, Codable {
    let moduleName: String
    let callName: String
}

extension CallCodingPath {
    var isTransfer: Bool {
        [.transfer, .transferKeepAlive].contains(self)
    }

    static var transfer: CallCodingPath {
        CallCodingPath(moduleName: "Balances", callName: "transfer")
    }

    static var transferKeepAlive: CallCodingPath {
        CallCodingPath(moduleName: "Balances", callName: "transfer_keep_alive")
    }

    static var addMemo: CallCodingPath {
        CallCodingPath(moduleName: "Crowdloan", callName: "add_memo")
    }

    static var nominationPoolJoin: CallCodingPath {
        CallCodingPath(moduleName: "NominationPools", callName: "Join")
    }

    static var createNominationPool: CallCodingPath {
        CallCodingPath(moduleName: "NominationPools", callName: "Create")
    }

    static var setPoolMetadata: CallCodingPath {
        CallCodingPath(moduleName: "NominationPools", callName: "set_metadata")
    }
}
