import Foundation
import SSFUtils

struct GeneralKeyV3: Codable, Equatable {
    @StringCodable var length: UInt32
    @BytesCodable var data: Data

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let length = try container.decode(UInt32.self, forKey: .length)
        _length = StringCodable(wrappedValue: length)

        let hexString = try container.decode(String.self, forKey: .data)
        let generalKey = (try? Data(hexStringSSF: hexString)) ?? Data(hexString.utf8)
        _data = BytesCodable(wrappedValue: generalKey)
    }

    init(lengh: UInt32, data: Data) {
        length = lengh
        self.data = data
    }
}
