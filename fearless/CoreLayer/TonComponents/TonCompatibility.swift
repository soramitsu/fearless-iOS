import Foundation
import SSFModels

#if canImport(TonSwift)
    import TonSwift

    extension TonSwift.Address {
        static func parse(accountId: Data, workchainId: Int32) throws -> TonSwift.Address {
            if let stored = try? JSONDecoder().decode(TonSwift.Address.self, from: accountId),
               stored.hash.count == 32 {
                return stored
            }
            guard accountId.count == 32, let workchain = Int8(exactly: workchainId) else {
                throw TonSendServiceError.invalidAccount
            }
            return TonSwift.Address(workchain: workchain, hash: accountId)
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
