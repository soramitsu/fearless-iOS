import Foundation
import FearlessUtils

final class StorageKeyExtractor {
    private enum Constants {
        static let hexSymbolsPerByte = 2
        static let uint32Bytes = 4
    }

    private let storageKey: Data

    init(storageKey: Data) {
        self.storageKey = storageKey
    }

    func extractU32Parameter() throws -> UInt32 {
        let keyString = storageKey.toHex()

        let idHexString = keyString.suffix(from: String.Index(
            utf16Offset: keyString.count - Constants.hexSymbolsPerByte * Constants.uint32Bytes,
            in: keyString
        ))
        let idData = try Data(hexString: String(idHexString))
        let decoder = try ScaleDecoder(data: idData)
        let uint32 = try UInt32(scaleDecoder: decoder)
        return uint32
    }
}
