import BigInt
import XCTest

@testable import SSFUtils

/// Events are identified by the variant index the metadata declares, like calls. None of the five
/// fixture chains has a gap in an event enum today, so this uses a hand-built V14 blob: one
/// pallet, `Example` (module index 7), whose event enum declares `Created(u32)` = 0,
/// `Renamed(u32, u32)` = 2 and `Removed` = 5. It was written with the encoder of
/// `scripts/trim-runtime-metadata.py`.
final class EventIndexTests: XCTestCase {
    private let metadataHex = [
        "6d6574610e08000000050500040c3870616c6c65745f6578616d706c651870616c6c6574144576656e74",
        "00010c1c43726561746564040000010c7533320000001c52656e616d6564080000010c753332000000010c",
        "7533320002001c52656d6f76656400050000041c4578616d706c650000010400000700040000",
    ].joined()

    private var metadata: RuntimeMetadata!
    private var catalog: TypeRegistryCatalog!

    override func setUpWithError() throws {
        try super.setUpWithError()
        metadata = try RuntimeMetadata(scaleDecoder: ScaleDecoder(data: Data(hex: metadataHex)))
        catalog = try TypeRegistryCatalog.createFromTypeDefinition(
            Data(#"{"types":{}}"#.utf8),
            runtimeMetadata: metadata,
            usedRuntimePaths: [:]
        )
    }

    func testEventsAreLookedUpByTheirDeclaredIndex() throws {
        let module = try XCTUnwrap(metadata.modules.first)

        XCTAssertEqual(try metadata.getEvent(in: module, at: 0)?.name, "Created")
        XCTAssertNil(try metadata.getEvent(in: module, at: 1))
        XCTAssertEqual(try metadata.getEvent(in: module, at: 2)?.name, "Renamed")
        XCTAssertNil(try metadata.getEvent(in: module, at: 3))
        XCTAssertEqual(try metadata.getEvent(in: module, at: 5)?.name, "Removed")
    }

    func testDecodingAnEventUsesItsIndexNotItsPosition() throws {
        // module 7, event 2 (Renamed), arguments 1 and 2 as u32
        let decoder = try DynamicScaleDecoder(
            data: Data([7, 2, 1, 0, 0, 0, 2, 0, 0, 0]),
            registry: catalog,
            version: 1
        )

        let event = try decoder.read(type: GenericType.event.name)

        XCTAssertEqual(event, .arrayValue([
            .unsignedIntValue(7),
            .unsignedIntValue(2),
            .arrayValue([.stringValue("1"), .stringValue("2")]),
        ]))
        XCTAssertEqual(decoder.remained, 0)
    }

    func testEncodingAnEventUsesItsIndex() throws {
        let encoder = DynamicScaleEncoder(registry: catalog, version: 1)

        try encoder.append(
            json: .arrayValue([.unsignedIntValue(7), .unsignedIntValue(5), .arrayValue([])]),
            type: GenericType.event.name
        )

        XCTAssertEqual(try encoder.encode(), Data([7, 5]))
    }

    func testAnEventIndexTheRuntimeDoesNotDeclareIsRefused() throws {
        // Position 1 is Renamed, but no event has index 1.
        let decoder = try DynamicScaleDecoder(
            data: Data([7, 1, 1, 0, 0, 0, 2, 0, 0, 0]),
            registry: catalog,
            version: 1
        )

        XCTAssertThrowsError(try decoder.read(type: GenericType.event.name)) { error in
            guard case GenericEventNodeError.unexpectedEventIndex(value: 1) = error else {
                return XCTFail("Expected unexpectedEventIndex(1), got \(error)")
            }
        }
    }

    func testMetadataWithoutEventIndexesUsesThePosition() throws {
        let metadata = try RuntimeMetadata.v1(
            modules: [
                RuntimeMetadataV1.ModuleMetadata(
                    name: "Pallet",
                    storage: nil,
                    calls: nil,
                    events: ["First", "Second"].map {
                        RuntimeMetadataV1.EventMetadata(name: $0, arguments: [], documentation: [])
                    },
                    constants: [],
                    errors: [],
                    index: 3
                ),
            ],
            extrinsic: RuntimeMetadataV1.ExtrinsicMetadata(version: 1, signedExtensions: [])
        )
        let module = try XCTUnwrap(metadata.modules.first)

        XCTAssertEqual(try metadata.getEvent(in: module, at: 1)?.name, "Second")
        XCTAssertNil(try metadata.getEvent(in: module, at: 2))
    }
}

/// Signed integers are little-endian two's complement in SCALE.
final class SignedIntegerDecodingTests: XCTestCase {
    private var catalog: TypeRegistryCatalog!

    override func setUpWithError() throws {
        try super.setUpWithError()
        catalog = try FixtureRuntime(.liberland).catalog
    }

    func testNegativeValuesDecodeFromTwosComplement() throws {
        let cases: [(
            bytes: [UInt8],
            read: (DynamicScaleDecoder) -> () throws -> JSON,
            value: String
        )] = [
            ([0xFF], { $0.readI8 }, "-1"),
            ([0x80], { $0.readI8 }, "-128"),
            ([0x7F], { $0.readI8 }, "127"),
            ([0x00], { $0.readI8 }, "0"),
            ([0xFE, 0xFF], { $0.readI16 }, "-2"),
            ([0x00, 0x00, 0x00, 0x80], { $0.readI32 }, "-2147483648"),
            ([0x01, 0, 0, 0, 0, 0, 0, 0], { $0.readI64 }, "1"),
            (Array(repeating: 0xFF, count: 16), { $0.readI128 }, "-1"),
            (
                Array(repeating: 0xFF, count: 15) + [0x7F],
                { $0.readI128 },
                String(BigInt(2).power(127) - 1)
            ),
            (
                [0x00] + Array(repeating: 0x00, count: 30) + [0x80],
                { $0.readI256 },
                String(-BigInt(2).power(255))
            ),
        ]

        for (bytes, read, value) in cases {
            let decoder = try DynamicScaleDecoder(data: Data(bytes), registry: catalog, version: 1)

            XCTAssertEqual(try read(decoder)(), .stringValue(value), "\(bytes)")
            XCTAssertEqual(decoder.remained, 0)
        }
    }

    func testSignedValuesRoundTripThroughTheEncoder() throws {
        let values: [(
            encode: (DynamicScaleEncoder) -> (JSON) throws -> Void,
            read: (DynamicScaleDecoder) -> () throws -> JSON,
            value: String
        )] = [
            ({ $0.appendI8 }, { $0.readI8 }, "-100"),
            ({ $0.appendI16 }, { $0.readI16 }, "-32768"),
            ({ $0.appendI32 }, { $0.readI32 }, "-123456789"),
            ({ $0.appendI64 }, { $0.readI64 }, "-9223372036854775808"),
            ({ $0.appendI128 }, { $0.readI128 }, "-170141183460469231731687303715884105728"),
            ({ $0.appendI256 }, { $0.readI256 }, "-5"),
        ]

        for (encode, read, value) in values {
            let encoder = DynamicScaleEncoder(registry: catalog, version: 1)
            try encode(encoder)(.stringValue(value))
            let decoder = try DynamicScaleDecoder(
                data: encoder.encode(),
                registry: catalog,
                version: 1
            )

            XCTAssertEqual(try read(decoder)(), .stringValue(value))
        }
    }
}
