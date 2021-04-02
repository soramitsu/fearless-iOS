import UIKit
import FearlessUtils

extension ChainData {
    var stringValue: String? {
        switch self {
        case .none:
            return nil
        case let .raw(data):
            return String(data: data, encoding: .utf8)
        case let .blakeTwo256(data), let .keccak256(data),
             let .sha256(data), let .shaThree256(data):
            return data.value.toHex(includePrefix: true)
        }
    }

    var imageValue: UIImage? {
        if case let .raw(data) = self {
            return UIImage(data: data)
        } else {
            return nil
        }
    }

    var dataValue: Data? {
        switch self {
        case .none:
            return nil
        case let .raw(data):
            return data
        case let .blakeTwo256(hash), let .keccak256(hash),
             let .sha256(hash), let .shaThree256(hash):
            return hash.value
        }
    }
}
