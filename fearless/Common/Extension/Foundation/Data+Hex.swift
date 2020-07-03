import Foundation
import IrohaCrypto

extension Data {
    func toHex(includePrefix: Bool = false) -> String {
        (includePrefix ? "0x" : "") + (self as NSData).toHexString()
    }

    init(hexString: String) throws {
        let prefix = "0x"
        if hexString.hasPrefix(prefix) {
            let filtered = String(hexString.suffix(hexString.count - prefix.count))
            self = (try NSData(hexString: filtered)) as Data
        } else {
            self = (try NSData(hexString: hexString)) as Data
        }
    }
}
