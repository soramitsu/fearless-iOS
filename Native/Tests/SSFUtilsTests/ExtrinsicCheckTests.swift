import Foundation
import XCTest
@testable import SSFUtils

final class ExtrinsicCheckTests: XCTestCase {
    private static let checks: [(String, ExtrinsicCheck)] = [
        ("CheckSpecVersion", .specVersion),
        ("CheckTxVersion", .txVersion),
        ("CheckGenesis", .genesis),
        ("CheckMortality", .mortality),
        ("CheckNonce", .nonce),
        ("CheckWeight", .weight),
        ("ChargeTransactionPayment", .txPayment),
        ("PrevalidateAttests", .attests),
        ("ChargeAssetTxPayment", .assetTxPayment),
        ("CheckAppId", .appCheck),
        // Appended so that the signature payload below keeps its first eight extensions.
        ("CheckMetadataHash", .checkMetadataHash)
    ]

    func testEveryCanonicalExtensionKeepsItsIdentity() throws {
        let metadata = try Self.metadata()
        XCTAssertEqual(Self.checks.count, ExtrinsicCheck.allCases.count)
        for (_, check) in Self.checks {
            XCTAssertEqual(
                ExtrinsicCheck.from(string: check.rawValue, runtimeMetadata: metadata),
                check
            )
        }
    }

    func testEveryExtensionAcceptsShortNamesNamespacesAndGenericParameters() throws {
        let metadata = try Self.metadata()
        for (name, check) in Self.checks {
            for prefix in ["", "custom::", "custom::nested::"] {
                for suffix in ["", "<T>", "<T: runtime::Config<Vec<U>>>"] {
                    let alias = prefix + name + suffix
                    XCTAssertEqual(
                        ExtrinsicCheck.from(string: alias, runtimeMetadata: metadata),
                        check,
                        alias
                    )
                }
            }
        }
    }

    func testUnknownAndSimilarNamesRemainUnsupported() throws {
        let metadata = try Self.metadata()
        for name in [
            "",
            "CheckUnknown",
            "checknonce",
            "CheckNonceExtra",
            "checkmetadatahash",
            "module::CheckMetadataHashV2<T>",
            "<T>::CheckNonce"
        ] {
            XCTAssertNil(ExtrinsicCheck.from(string: name, runtimeMetadata: metadata), name)
        }
    }

    func testResolutionDoesNotDependOnMetadataInstanceOrReservedPrefix() throws {
        // Real SCALE metadata shares the little-endian "meta" prefix across networks.
        let prefixes: [UInt32] = [0x6174_656D, 0x6174_656D, 1, 14, .max]
        for reserved in prefixes {
            let metadata = try Self.metadata(reserved: reserved)
            for (name, check) in Self.checks {
                XCTAssertEqual(
                    ExtrinsicCheck.from(string: "network::\(name)<T>", runtimeMetadata: metadata),
                    check
                )
            }
        }
    }

    func testConcurrentFreshAliasesAndRepeatedLookupsRemainDeterministic() throws {
        let metadata = try (0 ..< 24).map { _ in try Self.metadata() }
        let failures = ConcurrentCheckFailures()
        DispatchQueue.concurrentPerform(iterations: metadata.count) { worker in
            for iteration in 0 ..< 256 {
                let (name, expected) = Self.checks[iteration % Self.checks.count]
                // Every initial lookup is cold even if other tests have already resolved aliases.
                let alias = "fresh_\(worker)_\(iteration)::\(name)<T: runtime::Config>"
                for _ in 0 ..< 2
                    where ExtrinsicCheck.from(string: alias, runtimeMetadata: metadata[worker]) != expected {
                    failures.record(alias)
                }
            }
        }
        XCTAssertEqual(failures.messages, [])
    }

    func testCanonicalAndAliasedExtrasMatchExactScaleBytes() throws {
        for names in [Self.checks.map { $0.1.rawValue }, Self.checks.map { "other::\($0.0)<T>" }] {
            let metadata = try Self.metadata(extensions: names + ["FutureZeroSizedExtension"])
            let encoder = try Self.encoder(metadata: metadata)
            let extra = ExtrinsicSignedExtra(era: .immortal, nonce: 34, tip: 5, appId: 9)
            try encoder.append(extra, ofType: GenericType.extrinsicExtra.name)
            // Immortal, compact nonce, ordinary tip, asset tip + None, compact app ID, disabled
            // metadata-hash mode.
            XCTAssertEqual(try encoder.encode(), Data([0, 136, 20, 20, 0, 36, 0]))
        }
    }

    func testCanonicalAndAliasedSignaturePayloadsMatchExactBytes() throws {
        for prefix in ["", "signature_alias::"] {
            XCTAssertEqual(try Self.signaturePayload(aliasPrefix: prefix), Self.expectedPayload)
        }
    }

    func testConcurrentSignaturePayloadsMatchExactBytes() {
        let failures = ConcurrentCheckFailures()
        DispatchQueue.concurrentPerform(iterations: 12) { worker in
            for iteration in 0 ..< 24 {
                do {
                    let prefix = "payload_\(worker)_\(iteration)::"
                    if try Self.signaturePayload(aliasPrefix: prefix) != Self.expectedPayload {
                        failures.record(prefix)
                    }
                } catch {
                    failures.record(String(describing: error))
                }
            }
        }
        XCTAssertEqual(failures.messages, [])
    }

    private static var expectedPayload: Data {
        // Call index 7/0 and u32 argument; extra; u32 spec/transaction versions; two hashes.
        Data([7, 0, 0x78, 0x56, 0x34, 0x12, 0, 136, 20, 4, 3, 2, 1, 7, 0, 0, 0])
            + Data(repeating: 0x11, count: 64)
    }

    private static func signaturePayload(aliasPrefix: String) throws -> Data {
        let names = checks.prefix(8).map { name, check in
            aliasPrefix.isEmpty ? check.rawValue : "\(aliasPrefix)\(name)<T>"
        }
        let metadata = try Self.metadata(extensions: names)
        let genesis = String(repeating: "11", count: 32)
        let builder = try ExtrinsicBuilder(
            specVersion: 0x0102_0304,
            transactionVersion: 7,
            genesisHash: genesis
        )
        .with(nonce: 34).with(tip: 5)
        .adding(call: RuntimeCall(
            moduleName: "Example", callName: "set_value",
            args: JSON.dictionaryValue(["value": .stringValue("305419896")])
        ))
        return try builder.buildSignature(
            encodingBy: encoder(metadata: metadata),
            metadata: metadata
        )
    }

    private static func metadata(
        reserved: UInt32 = 0x6174_656D, extensions: [String] = []
    ) throws -> RuntimeMetadata {
        let module = RuntimeMetadataV1.ModuleMetadata(
            name: "Example", storage: nil,
            calls: [.init(
                name: "set_value",
                arguments: [.init(name: "value", type: "u32")],
                documentation: []
            )],
            events: nil, constants: [], errors: [], index: 7
        )
        return try RuntimeMetadata(
            wrapping: RuntimeMetadataV1(
                modules: [module], extrinsic: .init(version: 4, signedExtensions: extensions)
            ),
            metaReserved: reserved, version: 12
        )
    }

    private static func encoder(metadata: RuntimeMetadata) throws -> DynamicScaleEncoder {
        let definition = Data(#"{"types":{"Index":"u32","Balance":"u128"}}"#.utf8)
        let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
            definition, runtimeMetadata: metadata, usedRuntimePaths: [:]
        )
        return DynamicScaleEncoder(registry: catalog, version: 1)
    }
}

private final class ConcurrentCheckFailures {
    private let lock = NSLock()
    private var recorded: [String] = []

    var messages: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func record(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        if recorded.count < 16 {
            recorded.append(message)
        }
    }
}
