import MocksBasket
import SSFCrypto
import SSFRuntimeCodingService
import SSFUtils
import XCTest

@testable import SSFStorageQueryKit

/// The key encoder each kind of request gets, checked by the storage keys it produces against the
/// Polkadot metadata fixture.
final class StorageRequestKeyEncodingWorkerFactoryTests: XCTestCase {
    private var codingFactory: RuntimeCoderFactoryProtocol!

    private let timestampNowKey = "f0c365c3cf59d671eb72da0e7a4113c49f1f0515f462cdcf84e0f1d6045dfcbb"
    private let crowdloanFundsKey = [
        "3d9cad2baf702e20b136f4c8900cd802",
        "b6f9671a19ef28ecb1e331fea3029098",
        "071ceff5b0f64d362e080000",
    ].joined()
    private let erasValidatorPrefsKey = [
        "5f3e4907f716ac89b6347d15ececedca",
        "682db92dde20a10d96d00ff0e9e221c0",
        "176ef2fb941d646249050000",
        "00339ea96e66b59c2c2a55b5b7e13a772e0b693c3b351d2fb5e5b4da18ac379ebdb2f1f2e7559776",
    ].joined()

    override func setUp() async throws {
        try await super.setUp()
        if codingFactory == nil {
            codingFactory = try await PolkadotRuntimeProvider()
                .buildRuntimeProvider()
                .fetchCoderFactory()
        }
    }

    func testSimpleAndPrefixRequestsUseThePlainKey() throws {
        for workerType in [StorageRequestWorkerType.simple, .prefix] {
            let encoder = buildEncoder(
                path: StoragePathMock.custom(moduleName: "Timestamp", itemName: "Now"),
                workerType: workerType
            )

            XCTAssertTrue(encoder is SimpleKeyEncodingWorker)
            XCTAssertEqual(try encoder.performEncoding().map { $0.toHex() }, [timestampNowKey])
        }
    }

    func testEncodableRequestsHashTheirParameter() throws {
        let path = StoragePathMock.custom(moduleName: "Crowdloan", itemName: "Funds")

        for workerType in [
            StorageRequestWorkerType.encodable(params: ["2094"]),
            .prefixEncodable(params: ["2094"]),
        ] {
            let encoder = buildEncoder(path: path, workerType: workerType)

            XCTAssertTrue(encoder is MapKeyEncodingWorker)
            XCTAssertEqual(try encoder.performEncoding().map { $0.toHex() }, [crowdloanFundsKey])
        }
    }

    func testNMapRequestsHashEveryKeyComponent() throws {
        let account = try AddressFactory.accountId(
            from: "1zugcag7cJVBtVRnFxv5Qftn7xKAnR6YJ9x4x3XLgGgmNnS",
            chainFormat: .sfSubstrate(0)
        )
        let encoder = buildEncoder(
            path: StoragePathMock.custom(moduleName: "Staking", itemName: "ErasValidatorPrefs"),
            workerType: .nMap(params: [[
                [NMapKeyParam(value: "1353")],
                [NMapKeyParam(value: account)],
            ]])
        )

        XCTAssertTrue(encoder is NMapKeyEncodingWorker)
        XCTAssertEqual(try encoder.performEncoding().map { $0.toHex() }, [erasValidatorPrefsKey])
    }

    func testAnUnknownStoragePathIsRefused() {
        let encoder = buildEncoder(
            path: StoragePathMock.custom(moduleName: "1", itemName: "2"),
            workerType: .encodable(params: ["param"])
        )

        XCTAssertThrowsError(try encoder.performEncoding())
    }

    private func buildEncoder(
        path: StoragePathMock,
        workerType: StorageRequestWorkerType
    ) -> StorageKeyEncoder {
        StorageRequestKeyEncodingWorkerFactoryDefault().buildFactory(
            storageCodingPath: path,
            workerType: workerType,
            codingFactory: codingFactory,
            storageKeyFactory: StorageKeyFactory()
        )
    }
}
