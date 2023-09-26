import Foundation
import SSFRuntimeCodingService

final class SubstrateCallFactoryAssembly {
    static func createCallFactory(
        for runtimeSpecVersion: RuntimeSpecVersion
    ) -> SubstrateCallFactoryProtocol {
        let version = runtimeSpecVersion.rawValue
        switch runtimeSpecVersion.rawValue {
        case _ where version >= 9430:
            return SubstrateCallFactoryV9430()
        case _ where version >= 9420:
            return SubstrateCallFactoryV9420()
        case _ where version >= 9390:
            return SubstrateCallFactoryV9390()
        default:
            return SubstrateCallFactoryDefault()
        }
    }

    static func createCallFactory(
        forSSF runtimeSpecVersion: SSFRuntimeCodingService.RuntimeSpecVersion
    ) -> SubstrateCallFactoryProtocol {
        let version = runtimeSpecVersion.rawValue
        switch runtimeSpecVersion.rawValue {
        case _ where version >= 9430:
            return SubstrateCallFactoryV9430()
        case _ where version >= 9420:
            return SubstrateCallFactoryV9420()
        case _ where version >= 9390:
            return SubstrateCallFactoryV9390()
        default:
            return SubstrateCallFactoryDefault()
        }
    }
}
