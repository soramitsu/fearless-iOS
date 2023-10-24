import Foundation
import BigInt

extension BigUInt {
    static func fromHexString(_ hex: String?) -> BigUInt? {
        guard let hex = hex else {
            return nil
        }
        let prefix = "0x"

        if hex.hasPrefix(prefix) {
            let filtered = String(hex.suffix(hex.count - prefix.count))
            return BigUInt(filtered, radix: 16)
        } else {
            return BigUInt(hex, radix: 16)
        }
    }

    func toHexString() -> String {
        let prefix = "0x"
        return prefix + String(self, radix: 16)
    }
}
