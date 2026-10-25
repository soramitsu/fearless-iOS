import Foundation
import IrohaCrypto

public extension Data {
    func toHex(includePrefix: Bool = false) -> String {
        (includePrefix ? "0x" : "") + (self as NSData).toHexString()
    }

    init(hexStringSSF: String) throws {
        let prefix = "0x"
        if hexStringSSF.hasPrefix(prefix) {
            let filtered = String(hexStringSSF.suffix(hexStringSSF.count - prefix.count))
            self = try (NSData(hexString: filtered)) as Data
        } else {
            self = try (NSData(hexString: hexStringSSF)) as Data
        }
    }
}
