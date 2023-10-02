import Foundation
import BigInt

public extension BigUInt {
    init?(string: String) {
        self.init(string, radix: 10)
    }
}
