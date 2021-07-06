import Foundation
import BigInt

struct SignerConfirmation {
    let moduleName: String
    let callName: String
    let amount: BigUInt?
    let extrinsicString: String
}
