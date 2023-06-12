import Foundation
import Web3

public extension BigUInt {
    init?(string: String) {
        self.init(string, radix: 10)
    }
}
