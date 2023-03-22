import Foundation

final class SubstrateCallFactoryAssembly {
    static func createCallFactory(
        for runtimeSpecVersion: RuntimeSpecVersion
    ) -> SubstrateCallFactoryProtocol {
        switch runtimeSpecVersion {
        case .v9370, .v9380:
            return SubstrateCallFactoryV9380()
        case .v9390:
            return SubstrateCallFactoryV9390()
        }
    }
}
