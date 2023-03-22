import Foundation
import BigInt
import FearlessUtils

class SubstrateCallFactoryV9390: SubstrateCallFactoryDefault {
    override func createPool(
        amount: BigUInt,
        root: MultiAddress,
        nominator: MultiAddress,
        bouncer: MultiAddress
    ) -> any RuntimeCallable {
        let args = CreatePoolCallV2(
            amount: amount,
            root: root,
            nominator: nominator,
            bouncer: bouncer
        )

        return RuntimeCall(
            callCodingPath: .createNominationPool,
            args: args
        )
    }
}
