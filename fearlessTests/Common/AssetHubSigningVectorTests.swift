import XCTest
import SSFUtils
import SSFModels
import BigInt
@testable import fearless

final class AssetHubSigningVectorTests: XCTestCase {
    /// The shared encoder that signs transfers on these hubs produces the same independent payloads.
    func testSharedBuilderMatchesIndependentPayloadsOnAllHubs() throws {
        for name in ["polkadot", "kusama", "westend"] {
            let runtime = try AssetHubRuntimeFixture(name: name)
            let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "asset-hub-\(name)-signing-vectors", withExtension: "json"))
            let vector = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            let mortal = try XCTUnwrap(vector["mortal"] as? [String: Any])
            for (era, expected) in [(Era.immortal, vector), (.mortal(period: 64, phase: 59), mortal)] {
                let call = RuntimeCall(moduleName: "Staking", callName: "bond", args: BondCall(controller: nil, value: 12345, payee: .staked))
                let block = try XCTUnwrap(expected["blockHash"] as? String)
                let builder = try ExtrinsicBuilder(
                    specVersion: runtime.factory.specVersion,
                    transactionVersion: runtime.factory.txVersion,
                    genesisHash: runtime.chainId
                )
                .with(address: MultiAddress.accoundId(try data(vector, "publicKey")))
                .with(nonce: 34).with(tip: 0).with(era: era, blockHash: block).adding(call: call)
                let payload = try builder.buildSignature(encodingBy: runtime.factory.createEncoder(), metadata: runtime.factory.metadata)
                XCTAssertEqual(payload, try data(expected, "payload"), name)
            }
        }
    }

    func testAllNativeHubsMatchIndependentImmortalAndMortalPayloadsAndEnvelopes() throws {
        // Exact production DOT/KSM catalogue record captured 28 October 2026; Westend has no record.
        let suppliedTypes = Data("""
        {"runtime_id":700,"types":{},"versioning":[{"runtime_range":[0,null],"types":{"Balance":"u128","Index":"u32","Phase":"93","Address":"152","ExtrinsicSignature":"293","ParaId":"35","17":"GenericEvent","244":"GenericCall"}}]}
        """.utf8)
        for (name, useCatalogue) in ["polkadot", "kusama", "westend"].flatMap({ name in [(name, false), (name, true)] }) {
            let types = useCatalogue && name != "westend" ? suppliedTypes : nil
            let runtime = try AssetHubRuntimeFixture(name: name, versioningData: types)
            let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "asset-hub-\(name)-signing-vectors", withExtension: "json"))
            let vector = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            let mortal = try XCTUnwrap(vector["mortal"] as? [String: Any])
            for (era, expected) in [(Era.immortal, vector), (.mortal(period: 64, phase: 59), mortal)] {
                let call = RuntimeCall(moduleName: "Staking", callName: "bond", args: BondCall(controller: nil, value: 12345, payee: .staked))
                let callEncoder = runtime.factory.createEncoder()
                try callEncoder.append(json: call.toScaleCompatibleJSON(), type: GenericType.call.name)
                XCTAssertEqual(try callEncoder.encode(), try data(vector, "bondCall"), name)
                let block = try XCTUnwrap(expected["blockHash"] as? String)
                let builder = try AssetHubExtrinsicBuilder(factory: runtime.factory, genesisHash: runtime.chainId)
                    .with(address: MultiAddress.accoundId(try data(vector, "publicKey")))
                    .with(nonce: 34).with(tip: 0).with(era: era, blockHash: block).adding(call: call)
                let extensions = try AssetHubSignedExtensions(factory: runtime.factory, genesis: Data(hexStringSSF: runtime.chainId), block: data(expected, "blockHash"), era: era, nonce: 34, tip: 0).encode()
                XCTAssertEqual(extensions.extra, try data(expected, "signedExtras"), name)
                XCTAssertEqual(extensions.additional, try data(expected, "additionalExtras"), name)
                let payload = try builder.buildSignature(encodingBy: runtime.factory.createEncoder(), metadata: runtime.factory.metadata)
                XCTAssertEqual(payload, try data(expected, "payload"), name)
                _ = try builder.signing(by: { _ in Data(repeating: 0, count: 64) }, of: .ed25519, using: runtime.factory.createEncoder(), metadata: runtime.factory.metadata)
                XCTAssertEqual(try builder.build(encodingBy: runtime.factory.createEncoder(), metadata: runtime.factory.metadata), try data(expected, "zeroSignatureExtrinsic"), name)
            }
        }
    }

    func testRejectsImmortalNonGenesisCheckpointAndNonCanonicalMortalEras() throws {
        let runtime = try AssetHubRuntimeFixture(name: "polkadot")
        let genesis = try Data(hexStringSSF: runtime.chainId)
        for era in [Era.mortal(period: 3, phase: 0), .mortal(period: 6, phase: 0), .mortal(period: 131_072, phase: 0), .mortal(period: 64, phase: 64), .mortal(period: 65536, phase: 1)] {
            XCTAssertThrowsError(try AssetHubSignedExtensions(factory: runtime.factory, genesis: genesis, block: genesis, era: era, nonce: 0, tip: 0).encode())
        }
        XCTAssertThrowsError(try AssetHubSignedExtensions(factory: runtime.factory, genesis: genesis, block: Data(repeating: 2, count: 32), era: .immortal, nonce: 0, tip: 0).encode())
    }

    func testUnknownExtensionsRequireBothZeroSizedTypesAndRequiredExtensionsCannotDisappearOrDuplicate() throws {
        for fault in ["extra", "additional", "missing", "duplicate"] {
            let runtime = try AssetHubRuntimeFixture(name: "polkadot", modifyingExtensions: { original in
                var extensions = original
                let empty = original.first { $0.identifier == "CheckSpecVersion" }!
                let numeric = original.first { $0.identifier == "CheckNonce" }!
                switch fault {
                case "extra": extensions.append(.init(identifier: "FutureExtension", type: numeric.type, additionalSigned: numeric.additionalSigned))
                case "additional": extensions.append(.init(identifier: "FutureExtension", type: empty.type, additionalSigned: empty.additionalSigned))
                case "missing": extensions.removeAll { $0.identifier == "CheckMetadataHash" }
                default: extensions.append(empty)
                }
                return extensions
            })
            let genesis = try Data(hexStringSSF: runtime.chainId)
            XCTAssertThrowsError(try AssetHubSignedExtensions(factory: runtime.factory, genesis: genesis, block: genesis, era: .immortal, nonce: 0, tip: 0).encode(), fault)
        }
        let runtime = try AssetHubRuntimeFixture(name: "polkadot", modifyingExtensions: { original in
            let empty = original.first { $0.identifier == "AuthorizeCall" }!
            return original + [.init(identifier: "FutureZeroSizedExtension", type: empty.type, additionalSigned: empty.additionalSigned)]
        })
        let genesis = try Data(hexStringSSF: runtime.chainId)
        XCTAssertEqual(try AssetHubSignedExtensions(factory: runtime.factory, genesis: genesis, block: genesis, era: .immortal, nonce: 34, tip: 0).encode().extra, Data([0, 136, 0, 0, 0]))
    }

    private func data(_ object: [String: Any], _ key: String) throws -> Data {
        try Data(hexStringSSF: XCTUnwrap(object[key] as? String))
    }
}
