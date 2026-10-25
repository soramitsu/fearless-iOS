import BigInt
import Foundation
import SSFUtils

enum XcmV1MultiassetFungibility: Codable {
    case fungible(amount: BigUInt)

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case let .fungible(amount):
            try container.encode("Fungible")
            try container.encode(StringCodable(wrappedValue: amount))
        }
    }
}

extension XcmV1MultiassetFungibility: Equatable {
    static func == (lhs: XcmV1MultiassetFungibility, rhs: XcmV1MultiassetFungibility) -> Bool {
        switch (lhs, rhs) {
        case let (.fungible(lhsValue), .fungible(rhsValue)):
            return lhsValue == rhsValue
        }
    }
}
