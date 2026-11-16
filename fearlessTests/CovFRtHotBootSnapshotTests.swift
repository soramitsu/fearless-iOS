import RobinHood
import SSFModels
import SSFUtils
import XCTest
@testable import fearless

final class CovFRtHotBootSnapshotTests: XCTestCase {
    private let versioning = Data("""
    {"runtime_id":700,"types":{},"versioning":[{"runtime_range":[0,null],"types":{"Balance":"u128","Index":"u32"}}]}
    """.utf8)

    func testSnapshotDecodesStoredMetadataWithChainTypes() throws {
        let metadata = try covFRtMetadataBytes()
        let item = fearless.RuntimeMetadataItem(chain: "covf-hub", version: 2_005_001, txVersion: 15, metadata: metadata)
        let factory = RuntimeHotBootSnapshotFactory(chainId: "covf-hub", runtimeItem: item, filesOperationFactory: CovFRtNoFiles())
        let operation = factory.createRuntimeSnapshotWrapper(usedRuntimePaths: [:], chainTypes: versioning)
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        let snapshot = try XCTUnwrap(try XCTUnwrap(operation.result).get())
        XCTAssertEqual(snapshot.specVersion, 2_005_001)
        XCTAssertEqual(snapshot.txVersion, 15)
        XCTAssertNotNil(snapshot.metadata.getStorageMetadata(in: "System", storageName: "Account"))
    }

    func testCorruptMetadataFailsTheSnapshot() throws {
        let item = fearless.RuntimeMetadataItem(chain: "covf-hub", version: 1, txVersion: 1, metadata: Data([0x01, 0x02]))
        let factory = RuntimeHotBootSnapshotFactory(chainId: "covf-hub", runtimeItem: item, filesOperationFactory: CovFRtNoFiles())
        let operation = factory.createRuntimeSnapshotWrapper(usedRuntimePaths: [:], chainTypes: versioning)
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        guard case .failure? = operation.result else {
            return XCTFail("Corrupt metadata must not produce a snapshot")
        }
    }

    func testReleasedFactoryProducesNoSnapshot() throws {
        let item = fearless.RuntimeMetadataItem(chain: "covf-hub", version: 1, txVersion: 1, metadata: try covFRtMetadataBytes())
        var factory: RuntimeHotBootSnapshotFactory? = RuntimeHotBootSnapshotFactory(
            chainId: "covf-hub", runtimeItem: item, filesOperationFactory: CovFRtNoFiles()
        )
        let operation = try XCTUnwrap(factory).createRuntimeSnapshotWrapper(usedRuntimePaths: [:], chainTypes: versioning)
        factory = nil
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        XCTAssertNil(factory)
        let value = try XCTUnwrap(operation.result).get()
        XCTAssertNil(value)
    }
}

func covFRtMetadataBytes() throws -> Data {
    let url = try XCTUnwrap(Bundle(for: CovFRtHotBootSnapshotTests.self).url(forResource: "asset-hub-polkadot-metadata-v14", withExtension: ""))
    let hex = try String(contentsOf: url).trimmingCharacters(in: .whitespacesAndNewlines)
    return try Data(hexStringSSF: hex)
}

final class CovFRtNoFiles: RuntimeFilesOperationFactoryProtocol {
    func fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?> { CompoundOperationWrapper(targetOperation: CovFFixtures.result(nil)) }
    func fetchChainsTypesOperation() -> CompoundOperationWrapper<Data?> { CompoundOperationWrapper(targetOperation: CovFFixtures.result(nil)) }
    func fetchChainTypesOperation(for _: ChainModel.Id) -> CompoundOperationWrapper<Data?> {
        CompoundOperationWrapper(targetOperation: CovFFixtures.result(nil))
    }

    func saveCommonTypesOperation(data _: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> {
        CompoundOperationWrapper(targetOperation: CovFFixtures.result(()))
    }

    func saveChainsTypesOperation(data _: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> {
        CompoundOperationWrapper(targetOperation: CovFFixtures.result(()))
    }

    func saveChainTypesOperation(for _: ChainModel.Id, data _: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> {
        CompoundOperationWrapper(targetOperation: CovFFixtures.result(()))
    }
}
