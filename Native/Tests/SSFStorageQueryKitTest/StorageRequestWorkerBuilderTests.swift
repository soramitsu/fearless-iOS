import MocksBasket
import SSFModels
import XCTest

@testable import SSFStorageQueryKit

final class StorageRequestWorkerBuilderTests: XCTestCase {
    func testSimple() throws {
        let builder = StorageRequestWorkerBuilderDefault<String>()
        let simpleWorker = builder.buildWorker(
            runtimeService: RuntimeCodingServiceProtocolMock(),
            connection: JSONRPCEngineMock(),
            storageRequestFactory: AsyncStorageRequestDefault(),
            type: .simple
        )
        XCTAssertTrue(simpleWorker is SimpleStorageRequestWorker<String>)
    }

    func testNMap() throws {
        let builder = StorageRequestWorkerBuilderDefault<String>()
        let simpleWorker = builder.buildWorker(
            runtimeService: RuntimeCodingServiceProtocolMock(),
            connection: JSONRPCEngineMock(),
            storageRequestFactory: AsyncStorageRequestDefault(),
            type: .nMap(params: [])
        )
        XCTAssertTrue(simpleWorker is NMapStorageRequestWorker<String>)
    }

    func testEnocodable() throws {
        let builder = StorageRequestWorkerBuilderDefault<String>()
        let simpleWorker = builder.buildWorker(
            runtimeService: RuntimeCodingServiceProtocolMock(),
            connection: JSONRPCEngineMock(),
            storageRequestFactory: AsyncStorageRequestDefault(),
            type: .encodable(params: [])
        )
        XCTAssertTrue(simpleWorker is EncodableStorageRequestWorker<String>)
    }
}
