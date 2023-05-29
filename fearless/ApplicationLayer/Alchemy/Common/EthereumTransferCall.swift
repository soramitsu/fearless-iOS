import Foundation
import BigInt

public final class EthereumTransferCall: EthereumCall {
    let to: String
    let value: BigUInt

    override public var methodSignature: String {
        "transfer(address,uint256)"
    }

    override public var arguments: [Any] {
        [to, value]
    }

    init(to: String, value: BigUInt) {
        self.to = to
        self.value = value

        super.init()
    }
}
