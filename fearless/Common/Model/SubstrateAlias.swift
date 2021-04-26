import Foundation

typealias AccountAddress = String
typealias AccountId = Data

extension AccountId {
    static func matchHex(_ value: String) -> AccountId? {
        guard let data = try? Data(hexString: value) else {
            return nil
        }

        return data.count == SubstrateConstants.accountIdLength ? data : nil
    }
}
