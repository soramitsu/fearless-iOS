import UIKit
import FearlessUtils

extension ChainData {
    var stringValue: String? {
        switch self {
        case .none:
            return nil
        case .raw(let data):
            return String(data: data, encoding: .utf8)
        case .blakeTwo256(let data), .keccak256(let data),
             .sha256(let data), .shaThree256(let data):
            return data.value.toHex(includePrefix: true)
        }
    }

    var imageValue: UIImage? {
        if case .raw(let data) = self {
            return UIImage(data: data)
        } else {
            return nil
        }
    }

    var dataValue: Data? {
        switch self {
        case .none:
            return nil
        case .raw(let data):
            return data
        case .blakeTwo256(let hash), .keccak256(let hash),
             .sha256(let hash), .shaThree256(let hash):
            return hash.value
        }
    }
}
