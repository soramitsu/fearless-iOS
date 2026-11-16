import BigInt
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import XCTest
@testable import fearless

final class CovFAccountInfoFetchingTests: XCTestCase {
    func testMissingRecordAndRepositoryFailureReturnNoBalance() async throws {
        let asset = CovFFixtures.asset()
        let fixture = CovFAccountFixture()
        let missing = await fixture.service.fetch(for: asset, accountId: CovFFixtures.account)
        XCTAssertEqual(missing.0, asset)
        XCTAssertNil(missing.1)
        XCTAssertEqual(fixture.repository.requestedIds, [try fixture.key(asset)])
        fixture.repository.failure = NSError(domain: "repository", code: 12)
        let failed = await fixture.service.fetch(for: asset, accountId: CovFFixtures.account)
        XCTAssertEqual(failed.0, asset)
        XCTAssertNil(failed.1)
    }

    func testEthereumRecordDecodesAndRejectsMalformedAndNullPayloads() async throws {
        let asset = CovFFixtures.asset(ethereum: true)
        let fixture = CovFAccountFixture()
        let expected = AccountInfo(ethBalance: 12345)
        try fixture.store(JSONEncoder().encode(expected), for: asset)
        let success = await fixture.service.fetch(for: asset, accountId: CovFFixtures.account)
        XCTAssertEqual(success.1, expected)
        for bytes in [Data("null".utf8), Data("broken".utf8)] {
            try fixture.store(bytes, for: asset)
            let missing = await fixture.service.fetch(for: asset, accountId: CovFFixtures.account)
            XCTAssertNil(missing.1)
        }
    }

    func testEverySubstrateStorageFamilyReturnsNilWithoutRuntime() async throws {
        for type in [SubstrateAssetType.normal, .ormlAsset, .assets, .equilibrium, .soraAsset] {
            for utility in [true, false] {
                let asset = CovFFixtures.asset(type: type, utility: utility)
                let fixture = CovFAccountFixture()
                try fixture.store(Data([0]), for: asset)
                let result = await fixture.service.fetch(for: asset, accountId: CovFFixtures.account)
                XCTAssertEqual(result.0, asset)
                XCTAssertNil(result.1, "\(type), utility \(utility)")
            }
        }
    }

    func testSubstrateFamiliesDecodeBalancesThroughSingleAndBatchAPIs() async throws {
        for sample in CovFAccountSample.all {
            let fixture = CovFAccountFixture()
            let asset = CovFFixtures.asset(type: sample.type, utility: sample.utility)
            let runtime = try sample.runtime(path: asset.storagePath)
            fixture.registry.runtime = runtime
            let encoder = runtime.factory.createEncoder()
            try encoder.append(json: CovFFixtures.json(sample.value), type: "CovFValue")
            let encoded = try encoder.encode()
            try fixture.store(encoded, for: asset)
            let single = await fixture.service.fetch(for: asset, accountId: CovFFixtures.account)
            XCTAssertEqual(single.0, asset)
            XCTAssertEqual(single.1?.data.free, 123, "\(sample.type)")
            XCTAssertEqual(single.1?.data.reserved, sample.reserved)
            XCTAssertEqual(single.1?.data.frozen, sample.frozen)

            let wallet = AccountGenerator.generateMetaAccount()
            let account = try XCTUnwrap(wallet.fetch(for: asset.chain.accountRequest())?.accountId)
            try fixture.store(encoded, for: asset, account: account)
            let batch = await fixture.service.fetch(for: [asset], wallet: wallet)
            XCTAssertEqual(Set(batch.keys), [asset])
            XCTAssertEqual(batch[asset]??.data.free, 123, "\(sample.type)")
            XCTAssertEqual(batch[asset]??.data.reserved, sample.reserved)
            XCTAssertEqual(batch[asset]??.data.frozen, sample.frozen)
        }
    }

    func testSubstrateFamiliesHandleDecodeAndRuntimeFailures() async throws {
        for sample in CovFAccountSample.all {
            let fixture = CovFAccountFixture()
            let asset = CovFFixtures.asset(type: sample.type, utility: sample.utility)
            let runtime = try sample.runtime(path: asset.storagePath)
            fixture.registry.runtime = runtime
            try fixture.store(Data(), for: asset)
            let malformed = await fixture.service.fetch(for: asset, accountId: CovFFixtures.account)
            XCTAssertNil(malformed.1)
            runtime.failure = NSError(domain: "runtime", code: 21)
            let unavailable = await fixture.service.fetch(for: asset, accountId: CovFFixtures.account)
            XCTAssertNil(unavailable.1)
        }
    }

    func testBatchEmptyAndMissingRecordsRetainRequestedAssets() async throws {
        let fixture = CovFAccountFixture()
        let wallet = AccountGenerator.generateMetaAccount()
        let asset = CovFFixtures.asset()
        let empty = await fixture.service.fetch(for: [], wallet: wallet)
        XCTAssertTrue(empty.isEmpty)
        let missing = await fixture.service.fetch(for: [asset, asset], wallet: wallet)
        XCTAssertEqual(Set(missing.keys), [asset])
        XCTAssertNil(missing[asset] ?? nil)
    }

    func testBatchMissingRuntimeKeepsEveryAssetWithNilBalance() async throws {
        for type in [SubstrateAssetType.normal, .ormlAsset, .assets, .equilibrium, .soraAsset] {
            let fixture = CovFAccountFixture()
            let wallet = AccountGenerator.generateMetaAccount()
            let asset = CovFFixtures.asset(type: type, utility: false)
            let account = try XCTUnwrap(wallet.fetch(for: asset.chain.accountRequest())?.accountId)
            try fixture.store(Data(), for: asset, account: account)
            let result = await fixture.service.fetch(for: [asset], wallet: wallet)
            XCTAssertEqual(Set(result.keys), [asset])
            XCTAssertNil(result[asset] ?? nil)
        }
    }

    func testBatchEthereumDeduplicatesKeysAndOmitsCorruptRecords() async throws {
        let fixture = CovFAccountFixture()
        let wallet = AccountGenerator.generateMetaAccount()
        let asset = CovFFixtures.asset(ethereum: true)
        let account = try XCTUnwrap(wallet.fetch(for: asset.chain.accountRequest())?.accountId)
        let expected = AccountInfo(ethBalance: 987)
        try fixture.store(JSONEncoder().encode(expected), for: asset, account: account)
        let result = try await fixture.service.fetchByUniqKey(for: [asset, asset], wallet: wallet)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[asset.uniqueKey(accountId: account)] ?? nil, expected)
        try fixture.store(Data("bad".utf8), for: asset, account: account)
        let invalid = await fixture.service.fetch(for: [asset], wallet: wallet)
        XCTAssertTrue(invalid.isEmpty)
    }
}

private final class CovFAccountFixture {
    let repository = CovFRepository<AccountInfoStorageWrapper>()
    let registry = CovFRegistry()
    let queue = OperationQueue()
    lazy var service = AccountInfoFetching(
        accountInfoRepository: AnyDataProviderRepository(repository), chainRegistry: registry, operationQueue: queue
    )

    func key(_ asset: ChainAsset, account: Data = CovFFixtures.account) throws -> String {
        try LocalStorageKeyFactory().createFromStoragePath(asset.storagePath, chainAssetKey: asset.uniqueKey(accountId: account))
    }

    func store(_ data: Data, for asset: ChainAsset, account: Data = CovFFixtures.account) throws {
        repository.items = [AccountInfoStorageWrapper(identifier: try key(asset, account: account), data: data)]
    }
}

private struct CovFAccountSample {
    let type: SubstrateAssetType
    let utility: Bool
    let value: [String: Any]
    let definitions: String
    let reserved: BigUInt
    let frozen: BigUInt

    func runtime(path: fearless.StorageCodingPath) throws -> CovFRuntime {
        try CovFFixtures.runtime(path: path, type: "CovFValue", definitions: definitions)
    }

    static var all: [CovFAccountSample] {
        let normal: [String: Any] = [
            "nonce": "3", "consumers": "1", "providers": "2",
            "data": ["free": "123", "reserved": "4", "frozen": "5", "flags": "0"]
        ]
        let normalTypes = """
        {"types":{"CovFValue":{"nonce":"u32","consumers":"u32","providers":"u32","data":"CovFData"},
        "CovFData":{"free":"u128","reserved":"u128","frozen":"u128","flags":"u128"}}}
        """
        let ormlTypes = #"{"types":{"CovFValue":{"free":"u128","reserved":"u128","frozen":"u128"}}}"#
        let orml = ["free": "123", "reserved": "4", "frozen": "5"]
        return [
            CovFAccountSample(type: .normal, utility: true, value: normal, definitions: normalTypes, reserved: 4, frozen: 5),
            CovFAccountSample(type: .soraAsset, utility: true, value: normal, definitions: normalTypes, reserved: 4, frozen: 5),
            CovFAccountSample(type: .ormlAsset, utility: false, value: orml, definitions: ormlTypes, reserved: 4, frozen: 5),
            CovFAccountSample(type: .soraAsset, utility: false, value: orml, definitions: ormlTypes, reserved: 4, frozen: 5),
            CovFAccountSample(type: .assets, utility: false, value: ["balance": "123"],
                              definitions: #"{"types":{"CovFValue":{"balance":"u128"}}}"#, reserved: 0, frozen: 0),
            CovFAccountSample(type: .equilibrium, utility: true,
                              value: ["nonce": "0", "consumers": "0", "providers": "1", "sufficients": "0",
                                      "data": ["V0", ["balance": [["1", ["Positive", "123"]]]]]],
                              definitions: """
                              {"types":{"CovFValue":{"nonce":"u32","consumers":"u32","providers":"u32",
                              "sufficients":"u32","data":"CovFEqData"},"CovFEqData":{"_enum":{"V0":"CovFEqV0"}},
                              "CovFEqV0":{"balance":"Vec<(u32,CovFPositive)>"},"CovFPositive":{"_enum":{"Positive":"u128"}}}}
                              """, reserved: 0, frozen: 0)
        ]
    }
}
