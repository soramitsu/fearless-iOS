import XCTest
@testable import SSFUtils

final class MetadataHashSignedExtensionTests: XCTestCase {
    func testDisabledModeIsIncludedInExtraAndAdditionalSigned() throws {
        for name in ["CheckMetadataHash", "frame_metadata_hash_extension::CheckMetadataHash", "frame_metadata_hash_extension::CheckMetadataHash<Runtime>"] {
            let (metadata, catalog) = try runtime(extensions: [name])
            let builder = ExtrinsicBuilder(specVersion: 1, transactionVersion: 1, genesisHash: "00")
            _ = try builder.adding(call: RuntimeCall(moduleName: "Test", callName: "ping", args: JSON.dictionaryValue([:])))
            let payload = try builder.buildSignature(
                encodingBy: DynamicScaleEncoder(registry: catalog, version: 1), metadata: metadata
            )
            // Pallet7/call0, disabled mode0, additional-signed Option::None0.
            XCTAssertEqual(payload, Data([7, 0, 0, 0]), name)
        }
    }

    func testLegacyRuntimeWithoutExtensionDoesNotGainBytes() throws {
        let (metadata, catalog) = try runtime(extensions: [])
        let builder = ExtrinsicBuilder(specVersion: 1, transactionVersion: 1, genesisHash: "00")
        _ = try builder.adding(call: RuntimeCall(moduleName: "Test", callName: "ping", args: JSON.dictionaryValue([:])))
        XCTAssertEqual(try builder.buildSignature(
            encodingBy: DynamicScaleEncoder(registry: catalog, version: 1), metadata: metadata
        ), Data([7, 0]))
    }

    func testExtraDecoderConsumesDisabledModeBeforeNextField() throws {
        let (metadata, catalog) = try runtime(extensions: ["CheckMetadataHash"])
        let decoder = try DynamicScaleDecoder(data: Data([0, 42]), registry: catalog, version: 1)
        _ = try ExtrinsicExtraNode(runtimeMetadata: metadata).accept(decoder: decoder)
        XCTAssertEqual(try decoder.readU8(), .stringValue("42"))
        XCTAssertEqual(decoder.remained, 0)
    }

    func testDecoderRefusesUnrepresentedEnabledOrReservedModes() throws {
        let (metadata, catalog) = try runtime(extensions: ["CheckMetadataHash"])
        for mode: UInt8 in [1, 2, 255] {
            let decoder = try DynamicScaleDecoder(data: Data([mode]), registry: catalog, version: 1)
            XCTAssertThrowsError(try ExtrinsicExtraNode(runtimeMetadata: metadata).accept(decoder: decoder))
        }
    }

    func testDecoderRefusesMissingMode() throws {
        let (metadata, catalog) = try runtime(extensions: ["CheckMetadataHash"])
        let decoder = try DynamicScaleDecoder(data: Data(), registry: catalog, version: 1)
        XCTAssertThrowsError(try ExtrinsicExtraNode(runtimeMetadata: metadata).accept(decoder: decoder))
    }

    private func runtime(extensions: [String]) throws -> (RuntimeMetadata, TypeRegistryCatalog) {
        let metadata = try RuntimeMetadata.v1(
            modules: [RuntimeMetadataV1.ModuleMetadata(
                name: "Test", storage: nil,
                calls: [RuntimeMetadataV1.FunctionMetadata(name: "ping", arguments: [], documentation: [])],
                events: nil, constants: [], errors: [], index: 7
            )],
            extrinsic: RuntimeMetadataV1.ExtrinsicMetadata(version: 4, signedExtensions: extensions)
        )
        let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
            Data(#"{"types":{}}"#.utf8), runtimeMetadata: metadata, usedRuntimePaths: [:]
        )
        return (metadata, catalog)
    }
}
