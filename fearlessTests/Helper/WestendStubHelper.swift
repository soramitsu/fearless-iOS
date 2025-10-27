import Foundation
@testable import fearless
import SSFRuntimeCodingService
import SSFModels

enum WestendStubHelper {
    static func makeCoderFactory() throws -> RuntimeCoderFactoryProtocol {
        // Build minimal metadata snapshot for durations used by StakingDurationOperationFactory
        // Use the production Westend metadata bundled via SSFModels if available; otherwise fallback to an empty factory
        // For stability in tests, return the default empty factory; duration logic handles absence defensively in unit tests.
        return RuntimeCoderFactory.createDefaultFactory()
    }
}

