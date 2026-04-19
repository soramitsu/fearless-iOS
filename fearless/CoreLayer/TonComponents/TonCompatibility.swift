import Foundation
import SSFModels

#if canImport(TonSwift)
    import TonSwift

    extension TonSwift.Address {
        static func parse(accountId: Data, workchainId: Int32) throws -> TonSwift.Address {
            TonSwift.Address(workchain: Int8(workchainId), hash: accountId)
        }

        var accountId: Data { hash }
    }
#endif

enum TonAssetType {
    case normal
    case jetton
    case none
}

extension Optional where Wrapped == SubstrateAssetType {
    var tonAssetType: TonAssetType {
        switch self {
        case .some(.normal):
            return .normal
        case .some:
            return .jetton
        case .none:
            return .none
        }
    }
}

extension Data {
    func tail(_ length: Int) -> Data {
        guard count > length else {
            return self
        }

        return suffix(length)
    }
}
