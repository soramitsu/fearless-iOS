import Foundation
import RobinHood
import SSFRuntimeCodingService
import SSFUtils
import XCTest
@testable import fearless

final class CovGVestingCallTests: XCTestCase {
    func testVestingClaimPicksTheVestCallAvailableInMetadata() throws {
        let metadata = try RuntimeHelper.createRuntimeMetadata("westend-metadata")
        let catalog = try RuntimeHelper.createTypeRegistryCatalog(
            from: "runtime-default", networkName: "runtime-westend", runtimeMetadata: metadata
        )
        let snapshot = RuntimeSnapshot(typeRegistryCatalog: catalog, specVersion: 48, txVersion: 4, metadata: metadata)
        let factory = SubstrateCallFactoryDefault(runtimeService: CovGSnapshotRuntime(snapshot: snapshot))
        let call = try factory.vestingClaim()
        XCTAssertEqual(call.moduleName, "Vesting")
        XCTAssertEqual(call.callName, "vest")
    }

    func testVestingClaimRequiresRuntimeSnapshot() {
        let factory = SubstrateCallFactoryDefault(runtimeService: CovGSnapshotRuntime(snapshot: nil))
        XCTAssertThrowsError(try factory.vestingClaim()) {
            guard case SubstrateCallFactoryError.metadataUnavailable = $0 else { return XCTFail("Wrong error \($0)") }
        }
    }
}

private final class CovGSnapshotRuntime: RuntimeProviderProtocol {
    let snapshot: RuntimeSnapshot?
    var runtimeSpecVersion: RuntimeSpecVersion = .defaultVersion

    init(snapshot: RuntimeSnapshot?) {
        self.snapshot = snapshot
    }

    func setup() {}
    func setupHot() {}
    func cleanup() {}
    func readySnapshot() async throws -> RuntimeSnapshot {
        guard let snapshot else { throw SSFRuntimeCodingService.RuntimeProviderError.providerUnavailable }
        return snapshot
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { try RuntimeCodingServiceStub.createWestendCodingFactory() }
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        try RuntimeCodingServiceStub.createWestendCodingFactory()
    }
}
