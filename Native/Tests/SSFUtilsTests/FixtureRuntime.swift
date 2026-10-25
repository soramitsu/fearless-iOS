import Foundation
import RuntimeMetadataFixtures
import XCTest

@testable import SSFUtils

/// Runtime metadata of a live chain together with the production type registry built from it.
struct FixtureRuntime {
    let fixture: RuntimeMetadataFixture
    let metadata: RuntimeMetadata
    let catalog: TypeRegistryCatalog

    var specVersion: UInt64 { UInt64(fixture.manifest.specVersion) }

    init(_ name: RuntimeMetadataFixture.Name) throws {
        fixture = try RuntimeMetadataFixture.load(name)
        metadata = try RuntimeMetadata(scaleDecoder: ScaleDecoder(data: fixture.metadata))
        catalog = try TypeRegistryCatalog.createFromTypeDefinition(
            Data(#"{"types":{}}"#.utf8),
            runtimeMetadata: metadata,
            usedRuntimePaths: [:]
        )
    }

    func encoder() -> DynamicScaleEncoder {
        DynamicScaleEncoder(registry: catalog, version: specVersion)
    }

    func encode(call: JSON) throws -> Data {
        let encoder = encoder()
        try encoder.append(json: call, type: GenericType.call.name)
        return try encoder.encode()
    }

    func decode(call data: Data) throws -> JSON {
        let decoder = try DynamicScaleDecoder(data: data, registry: catalog, version: specVersion)
        let call = try decoder.read(type: GenericType.call.name)
        XCTAssertEqual(decoder.remained, 0, "the call must consume every byte")
        return call
    }
}

extension JSON {
    /// `["Name", payload]`, how the dynamic encoder takes an enum variant.
    static func variant(_ name: String, _ payload: JSON = .null) -> JSON {
        .arrayValue([.stringValue(name), payload])
    }

    static func bytes(_ data: Data) -> JSON {
        .arrayValue(data.map { .stringValue(String($0)) })
    }

    static func call(_ module: String, _ call: String, _ args: [String: JSON]) -> JSON {
        .arrayValue([
            .stringValue(module),
            .arrayValue([.stringValue(call), .dictionaryValue(args)]),
        ])
    }
}

extension Data {
    init(hex: String) {
        precondition(hex.count.isMultiple(of: 2), "odd number of hex digits")
        var bytes = [UInt8]()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            bytes.append(UInt8(hex[index ..< next], radix: 16)!)
            index = next
        }
        self.init(bytes)
    }

    var hex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
