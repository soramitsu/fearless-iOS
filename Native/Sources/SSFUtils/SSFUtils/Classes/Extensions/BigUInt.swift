import BigInt
import Foundation

public extension BigUInt {
    init?(string: String) {
        self.init(string, radix: 10)
    }
}
