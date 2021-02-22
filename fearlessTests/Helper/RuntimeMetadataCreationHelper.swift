import Foundation
import FearlessUtils
import RobinHood
@testable import fearless

final class RuntimeMetadataCreationHelper {
    static func persistTestRuntimeMetadata(for identifier: String,
                                           specVersion: UInt32,
                                           txVersion: UInt32,
                                           using repository: AnyDataProviderRepository<RuntimeMetadataItem>,
                                           operationManager: OperationManager) throws {
        let url = Bundle(for: self).url(forResource: "runtimeTestMetadata", withExtension: "")!
        let hex = try String(contentsOf: url).trimmingCharacters(in: .whitespacesAndNewlines)
        let data = try Data(hexString: hex)
        let item = RuntimeMetadataItem(chain: identifier, version: specVersion, txVersion: txVersion, metadata: data)

        let operation = repository.saveOperation({ [item] }, { [] })
        operationManager.enqueue(operations: [operation], in: .transient)
    }
}
