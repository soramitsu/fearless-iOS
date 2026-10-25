import MocksBasket
import XCTest

@testable import SSFStorageQueryKit

final class EncodableStorageRequestWorkerTests: XCTestCase {
    func testEncodableStorageRequestWorker() async throws {
        let worker = EncodableStorageRequestWorker<String>(
            runtimeService: RuntimeCodingServiceProtocolMock(),
            connection: JSONRPCEngineMock(),
            storageRequestFactory: AsyncStorageRequestDefault()
        )
        let request = StorageRequestMock(
            parametersType: .simple,
            storagePath: StoragePathMock.custom(moduleName: "", itemName: "")
        )

        do {
            let _: [StorageResponse<String>] = try await worker.perform(
                params: request.parametersType.workerType,
                storagePath: request.storagePath
            )
            XCTFail("Error needs to be thrown")
        } catch {
            XCTAssertTrue(true)
        }
    }

    func testNMapStorageRequestWorker() async throws {
        let worker = NMapStorageRequestWorker<String>(
            runtimeService: RuntimeCodingServiceProtocolMock(),
            connection: JSONRPCEngineMock(),
            storageRequestFactory: AsyncStorageRequestDefault()
        )
        let request = StorageRequestMock(
            parametersType: .simple,
            storagePath: StoragePathMock.custom(moduleName: "", itemName: "")
        )

        do {
            let _: [StorageResponse<String>] = try await worker.perform(
                params: request.parametersType.workerType,
                storagePath: request.storagePath
            )
            XCTFail("Error needs to be thrown")
        } catch {
            XCTAssertTrue(true)
        }
    }

    func testSimpleStorageRequestWorker() async throws {
        let worker = SimpleStorageRequestWorker<String>(
            runtimeService: RuntimeCodingServiceProtocolMock(),
            connection: JSONRPCEngineMock(),
            storageRequestFactory: AsyncStorageRequestDefault()
        )
        let request = StorageRequestMock(
            parametersType: .encodable(param: "P"),
            storagePath: StoragePathMock.custom(moduleName: "", itemName: "")
        )

        do {
            let _: [StorageResponse<String>] = try await worker.perform(
                params: request.parametersType.workerType,
                storagePath: request.storagePath
            )
            XCTFail("Error needs to be thrown")
        } catch {
            XCTAssertTrue(true)
        }
    }
}
