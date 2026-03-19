#if canImport(TonSwift)
    import Foundation
    import TonSwift

    extension TonSwift.Address {
        static func parse(accountId: Data, workchainId: Int32) throws -> TonSwift.Address {
            TonSwift.Address(workchain: Int8(workchainId), hash: accountId)
        }

        var accountId: Data { hash }
    }
#endif

extension Data {
    func tail(_ length: Int) -> Data {
        guard count > length else {
            return self
        }

        return suffix(length)
    }
}
