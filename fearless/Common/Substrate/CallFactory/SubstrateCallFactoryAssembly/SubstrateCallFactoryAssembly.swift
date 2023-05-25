import Foundation

final class SubstrateCallFactoryAssembly {
    static func createCallFactory(
        for runtimeSpecVersion: RuntimeSpecVersion
    ) -> SubstrateCallFactoryProtocol {
        let version = runtimeSpecVersion.rawValue
        switch runtimeSpecVersion.rawValue {
        case _ where version >= 9420:
            return SubstrateCallFactoryV9420()
        case _ where version >= 9390:
            return SubstrateCallFactoryV9390()
        default:
            return SubstrateCallFactoryDefault()
        }
    }
}
