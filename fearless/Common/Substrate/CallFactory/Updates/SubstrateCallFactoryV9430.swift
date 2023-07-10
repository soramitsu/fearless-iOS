import Foundation
import BigInt
import SSFUtils
import SSFModels

class SubstrateCallFactoryV9430: SubstrateCallFactoryV9420 {
    override func setController(_: AccountAddress, chainAsset _: ChainAsset) throws -> any RuntimeCallable {
        let path: SubstrateCallPath = .setController
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName
        )
    }
}
