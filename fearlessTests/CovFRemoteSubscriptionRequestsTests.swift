import RobinHood
import SSFUtils
import SSFRuntimeCodingService
import XCTest
@testable import fearless

final class CovFRemoteSubscriptionRequestsTests: XCTestCase {
    func testUnkeyedStorageRequestUsesStoragePrefixAndKeepsLocalKey() throws {
        let factory = try CovFSubscriptionRuntime.make()
        let request = UnkeyedSubscriptionRequest(storagePath: .activeEra, localKey: "local-era")
        let wrapper = request.createKeyEncodingWrapper(using: StorageKeyFactory(), codingFactoryClosure: { factory })
        XCTAssertEqual(try CovFFixtures.execute(wrapper), try StorageKeyFactory().key(from: .activeEra))
        XCTAssertEqual(request.localKey, "local-era")
    }

    func testMapStorageRequestIncludesAccountAndChangesWithAccount() throws {
        let factory = try CovFSubscriptionRuntime.make()
        var keys: [Data] = []
        for byte: UInt8 in [1, 2] {
            let account = Data(repeating: byte, count: 32)
            let request = MapSubscriptionRequest(storagePath: .controller, localKey: "controller", keyParamClosure: { account })
            let key = try CovFFixtures.execute(request.createKeyEncodingWrapper(using: StorageKeyFactory(), codingFactoryClosure: { factory }))
            XCTAssertTrue(key.starts(with: try StorageKeyFactory().key(from: .controller)))
            XCTAssertTrue(key.suffix(32).elementsEqual(account))
            XCTAssertEqual(request.localKey, "controller")
            keys.append(key)
        }
        XCTAssertNotEqual(keys[0], keys[1])
    }

    func testDoubleAndNMapStorageRequestsEncodeEraAndValidator() throws {
        let factory = try CovFSubscriptionRuntime.make()
        let account = CovFFixtures.account
        let double = DoubleMapSubscriptionRequest(
            storagePath: .validatorExposureClipped, localKey: "exposure", keyParamClosure: { (fearless.StringScaleMapper(value: UInt32(7)), account) }
        )
        let nmap = NMapSubscriptionRequest(
            storagePath: .validatorExposureClipped, localKey: "exposure",
            keyParamClosure: { [[NMapKeyParam(value: "7")], [NMapKeyParam(value: account)]] }
        )
        let doubleKey = try CovFFixtures.execute(double.createKeyEncodingWrapper(using: StorageKeyFactory(), codingFactoryClosure: { factory }))
        let nmapFactory = try CovFSubscriptionRuntime.make(nmap: true)
        let nmapKey = try CovFFixtures.execute(nmap.createKeyEncodingWrapper(using: StorageKeyFactory(), codingFactoryClosure: { nmapFactory }))
        XCTAssertEqual(doubleKey, nmapKey)
        XCTAssertTrue(doubleKey.starts(with: try StorageKeyFactory().key(from: .validatorExposureClipped)))
        XCTAssertTrue(doubleKey.suffix(32).elementsEqual(account))
        XCTAssertEqual(double.localKey, nmap.localKey)
    }

    func testEveryRequestPropagatesRuntimeConfigurationFailure() throws {
        let error = NSError(domain: "runtime", code: 10)
        let requests: [SubscriptionRequestProtocol] = [
            UnkeyedSubscriptionRequest(storagePath: .activeEra, localKey: "era"),
            MapSubscriptionRequest(storagePath: .controller, localKey: "controller", keyParamClosure: { CovFFixtures.account }),
            DoubleMapSubscriptionRequest(storagePath: .validatorExposureClipped, localKey: "exposure", keyParamClosure: { ("7", CovFFixtures.account) }),
            NMapSubscriptionRequest(storagePath: .validatorExposureClipped, localKey: "exposure", keyParamClosure: { [] })
        ]
        for request in requests {
            let wrapper = request.createKeyEncodingWrapper(using: StorageKeyFactory(), codingFactoryClosure: { throw error })
            XCTAssertThrowsError(try CovFFixtures.execute(wrapper)) { XCTAssertEqual($0 as NSError, error) }
        }
    }
}

private enum CovFSubscriptionRuntime {
    static func make(nmap: Bool = false) throws -> RuntimeCoderFactoryProtocol {
        let exposure: StorageEntryType = nmap
            ? .nMap(NMapEntry(keysStrings: ["u32", "AccountId"], hashers: [.twox64Concat, .blake128Concat], valueString: "u32"))
            : .doubleMap(DoubleMapEntry(hasher: .twox64Concat, key1: "u32", key2: "AccountId", value: "u32", key2Hasher: .blake128Concat))
        let entries = [
            RuntimeMetadataV1.StorageEntryMetadata(name: "ActiveEra", modifier: .optional, type: .plain(PlainEntry(stringValue: "u32")),
                                                  defaultValue: Data(), documentation: []),
            RuntimeMetadataV1.StorageEntryMetadata(name: "Bonded", modifier: .optional,
                                                  type: .map(MapEntry(hasher: .blake128Concat, key: "AccountId", value: "AccountId", unused: false)),
                                                  defaultValue: Data(), documentation: []),
            RuntimeMetadataV1.StorageEntryMetadata(name: "ErasStakersClipped", modifier: .optional, type: exposure,
                                                  defaultValue: Data(), documentation: [])
        ]
        let module = RuntimeMetadataV1.ModuleMetadata(name: "Staking", storage: .init(prefix: "Staking", entries: entries),
                                                     calls: nil, events: nil, constants: [], errors: [], index: 0)
        let metadata = try RuntimeMetadata.v1(modules: [module], extrinsic: .init(version: 4, signedExtensions: []))
        let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
            Data(#"{"types":{"AccountId":"[u8; 32]"}}"#.utf8), runtimeMetadata: metadata, usedRuntimePaths: [:]
        )
        return TestRuntimeCoderFactory(catalog: catalog, specVersion: 1, txVersion: 1, metadata: metadata)
    }
}
