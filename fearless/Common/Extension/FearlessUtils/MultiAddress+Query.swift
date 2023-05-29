import Foundation
import SSFUtils

extension MultiAddress {
    var accountId: Data? {
        if case let .accoundId(value) = self {
            return value
        } else {
            return nil
        }
    }
}
