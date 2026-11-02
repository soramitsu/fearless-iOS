import XCTest
import Foundation
import SSFModels
import SSFUtils
import BigInt
@testable import fearless

final class AssetHubRuntimeContractTests: XCTestCase {
    func testCurrentNativeMetadataHasModernStakingStorageAndPagedCalls() throws {
        for name in ["polkadot", "kusama", "westend"] {
            let runtime = try AssetHubRuntimeFixture(name: name)
            for path in [fearless.StorageCodingPath.activeEra, .bondedEras, .erasStakersPaged, .claimedRewards, .lastValidatorEra, .validatorSlashInEra] {
                XCTAssertNotNil(runtime.factory.metadata.getStorageMetadata(for: path), "\(name): \(path)")
            }
            XCTAssertNil(runtime.factory.metadata.getStorageMetadata(for: .eraStartSessionIndex))
            XCTAssertNil(runtime.factory.metadata.getStorageMetadata(for: .slashingSpans))
            XCTAssertNotNil(runtime.factory.metadata.getConstant(in: "Staking", constantName: "MaxExposurePageSize"))
            let call = try SubstrateCallFactoryDefault(runtimeService: runtime).payout(validatorId: Data(repeating: 7, count: 32), era: 34, page: 2)
            XCTAssertEqual(call.callName, "payout_stakers_by_page")
            let encoder = runtime.factory.createEncoder()
            try encoder.append(json: call.toScaleCompatibleJSON(), type: GenericType.call.name)
            XCTAssertFalse(try encoder.encode().isEmpty)
        }
    }

    func testNativeExtraEncodesMetadataHashModeAndAdditionalNoneOnAllHubs() throws {
        for name in ["polkadot", "kusama", "westend"] {
            let runtime = try AssetHubRuntimeFixture(name: name)
            let genesis = try Data(hexStringSSF: runtime.chainId)
            let extensions = try AssetHubSignedExtensions(
                factory: runtime.factory,
                genesis: genesis,
                block: genesis,
                era: .immortal,
                nonce: 34,
                tip: 0
            ).encode()
            // immortal, compact nonce 34, compact tip 0, native fee asset None, metadata mode Disabled.
            XCTAssertEqual(extensions.extra, Data([0, 136, 0, 0, 0]), name)
            XCTAssertEqual(
                extensions.additional,
                try runtime.factory.specVersion.scaleEncoded() + runtime.factory.txVersion.scaleEncoded() + genesis + genesis + Data([0]),
                name
            )
        }
    }

    func testSharedBuilderAndAssetHubBuilderSignTheSamePayloadOnCurrentHubs() throws {
        for name in ["polkadot", "kusama", "westend"] {
            let runtime = try AssetHubRuntimeFixture(name: name)
            let call = SubstrateCallFactoryDefault(runtimeService: runtime).chill()
            let shared = try ExtrinsicBuilder(
                specVersion: runtime.factory.specVersion,
                transactionVersion: runtime.factory.txVersion,
                genesisHash: runtime.chainId
            )
            .with(nonce: 34).adding(call: call)
            let hub = try AssetHubExtrinsicBuilder(factory: runtime.factory, genesisHash: runtime.chainId)
                .with(nonce: 34).adding(call: call)
            let sharedPayload = try shared.buildSignature(encodingBy: runtime.factory.createEncoder(), metadata: runtime.factory.metadata)
            let hubPayload = try hub.buildSignature(encodingBy: runtime.factory.createEncoder(), metadata: runtime.factory.metadata)
            XCTAssertEqual(hubPayload, sharedPayload, name)
        }
    }

    func testBuilderSignsExactPayloadAndInvalidatesSignatureAfterCallMutation() throws {
        let runtime = try AssetHubRuntimeFixture(name: "kusama")
        let calls = SubstrateCallFactoryDefault(runtimeService: runtime)
        let builder = try AssetHubExtrinsicBuilder(factory: runtime.factory, genesisHash: runtime.chainId)
            .with(address: MultiAddress.accoundId(Data(repeating: 3, count: 32)))
            .with(nonce: 34).with(tip: 0).with(appId: 0).adding(call: calls.chill())
        let payload = try builder.buildSignature(encodingBy: runtime.factory.createEncoder(), metadata: runtime.factory.metadata)
        var signed: Data?
        _ = try builder.signing(
            by: { signed = $0; return Data(repeating: 4, count: 64) },
            of: .sr25519,
            using: runtime.factory.createEncoder(),
            metadata: runtime.factory.metadata
        )
        XCTAssertEqual(signed, payload)
        let encoded = try builder.build(encodingBy: runtime.factory.createEncoder(), metadata: runtime.factory.metadata)
        let decoder = try ScaleDecoder(data: encoded)
        _ = try BigUInt(scaleDecoder: decoder)
        let version = try UInt8(scaleDecoder: decoder)
        XCTAssertEqual(version, 0x84)
        _ = try builder.adding(call: calls.unbond(amount: 123))
        let unsigned = try builder.build(encodingBy: runtime.factory.createEncoder(), metadata: runtime.factory.metadata)
        let unsignedDecoder = try ScaleDecoder(data: unsigned)
        _ = try BigUInt(scaleDecoder: unsignedDecoder)
        let unsignedVersion = try UInt8(scaleDecoder: unsignedDecoder)
        XCTAssertEqual(unsignedVersion, 4)
        XCTAssertNotEqual(try builder.buildSignature(encodingBy: runtime.factory.createEncoder(), metadata: runtime.factory.metadata), payload)
    }

    func testBuilderRejectsWrongGenesisMissingNonceInvalidBlockAndUnsupportedAppId() throws {
        let runtime = try AssetHubRuntimeFixture(name: "polkadot")
        XCTAssertThrowsError(try AssetHubExtrinsicBuilder(factory: runtime.factory, genesisHash: String(repeating: "00", count: 32)))
        let builder = try AssetHubExtrinsicBuilder(factory: runtime.factory, genesisHash: runtime.chainId)
            .adding(call: SubstrateCallFactoryDefault(runtimeService: runtime).chill())
        XCTAssertThrowsError(try builder.buildSignature(encodingBy: runtime.factory.createEncoder(), metadata: runtime.factory.metadata))
        _ = builder.with(nonce: 0).with(appId: 1)
        XCTAssertThrowsError(try builder.buildSignature(encodingBy: runtime.factory.createEncoder(), metadata: runtime.factory.metadata))
        _ = builder.with(appId: 0).with(era: .immortal, blockHash: "invalid")
        XCTAssertThrowsError(try builder.buildSignature(encodingBy: runtime.factory.createEncoder(), metadata: runtime.factory.metadata))
    }

    func testNMapKeyDecodeUsesCapturedMetadataAndRejectsWrongLengthAndPrefix() throws {
        let runtime = try AssetHubRuntimeFixture(name: "westend")
        let scanner = AssetHubPagedStorage(engine: MockConnection(), runtime: runtime.factory, block: Data(repeating: 0, count: 32), storage: AsyncStorageRequestDefault())
        let account = Data(repeating: 8, count: 32)
        let keys = try NMapKeyEncodingWorker(
            codingFactory: runtime.factory,
            path: fearless.StorageCodingPath.erasStakersPaged,
            storageKeyFactory: StorageKeyFactory(),
            keyParams: [[
                [NMapKeyParam(value: StringScaleMapper(value: UInt32(12)))],
                [NMapKeyParam(value: account)],
                [NMapKeyParam(value: StringScaleMapper(value: UInt32(3)))]
            ]]
        ).performEncoding()
        let key = try XCTUnwrap(keys.first)
        let decoded: ErasStakersPagedKey = try scanner.decodeKey(key, path: .erasStakersPaged, type: .erasStakersPagedKey)
        XCTAssertEqual(decoded.era, 12)
        XCTAssertEqual(decoded.accountId, account)
        XCTAssertEqual(decoded.page, 3)
        XCTAssertThrowsError(try scanner.decodeKey(key.dropLast(), path: .erasStakersPaged, type: .erasStakersPagedKey) as ErasStakersPagedKey)
        XCTAssertThrowsError(try scanner.decodeKey(key, path: .claimedRewards, type: .erasStakersPagedKey) as ErasStakersPagedKey)
    }
}
