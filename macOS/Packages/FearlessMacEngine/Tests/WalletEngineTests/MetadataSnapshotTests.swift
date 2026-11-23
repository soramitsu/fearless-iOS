import Foundation
import WalletCore
import XCTest
@testable import WalletEngine

final class MetadataSnapshotTests: XCTestCase {
    func testCapturedMetadataMatchesAllFiveVerifiedRuntimes() throws {
        let snapshots = MetadataSnapshot.all
        XCTAssertEqual(
            Set(snapshots.map(\.genesis)),
            Set(Catalog.networks.filter { $0.prefix != nil }.map { $0.id.rawValue })
        )
        for snapshot in snapshots {
            let bytes = try snapshot.bytes(for: snapshot.codeHash)
            XCTAssertTrue(bytes.starts(with: [109, 101, 116, 97, 14]))
            XCTAssertThrowsError(try snapshot.bytes(for: "changed-runtime"))
        }
        let sample = try XCTUnwrap(snapshots.first)
        let damaged = MetadataSnapshot(
            genesis: sample.genesis,
            codeHash: sample.codeHash,
            file: sample.file,
            sha256: String(repeating: "0", count: 64),
            specVersion: sample.specVersion,
            transactionVersion: sample.transactionVersion
        )
        XCTAssertThrowsError(try damaged.bytes(for: sample.codeHash))
    }
}

extension MetadataSnapshotTests {
    func testAllCatalogCallPinsAndSignedExtensionOrdersMatchSnapshots() throws {
        for snapshot in MetadataSnapshot.all {
            let id = ChainID(snapshot.genesis)
            let runtime = try SubstrateRuntime(
                data: snapshot.bytes(for: snapshot.codeHash),
                spec: snapshot.specVersion,
                transaction: snapshot.transactionVersion
            )
            let pins = try XCTUnwrap(Catalog.chain(id).signing)
            let address = Data(repeating: 2, count: 32)
            let context = SubstrateRuntime.SigningContext(sender: address, nonce: 1, height: 1, block: "0x" + snapshot.genesis)
            for keep in [true, false] {
                _ = try runtime.builder(dest: address, asset: .native(id), amount: 99999, keepAlive: keep, context: context)
            }
            XCTAssertEqual(pins.assets, runtime.metadata.getModuleIndex("Assets"))
            if pins.assets != nil {
                _ = try runtime.builder(
                    dest: address,
                    asset: AssetID(chainID: id, key: "asset:1337"),
                    amount: 1,
                    keepAlive: true,
                    context: context
                )
            }
        }
    }

    func testSwappedCallIndicesAndSwappedExtensionsRefuseSigning() throws {
        let snapshot = try XCTUnwrap(MetadataSnapshot.all.first { $0.file == "metadata-polkadot.scale.deflate" })
        let original = try snapshot.bytes(for: snapshot.codeHash)
        // Locations of the V14 call indices and contiguous SignedExtensionMetadata entries
        // decoded independently using @polkadot/types against this capture's SHA-256.
        var calls = original
        XCTAssertEqual(calls[45558], 0)
        XCTAssertEqual(calls[46167], 3)
        calls.swapAt(45558, 46167)
        var extensions = original
        extensions.replaceSubrange(412_708 ..< 412_740, with: original[412_726 ..< 412_740] + original[412_708 ..< 412_726])
        for (bytes, reason) in [(calls, "Runtime transfer call differs from the reviewed encoding."),
                                (extensions, "Unexpected signed extension order.")] {
            let runtime = try SubstrateRuntime(data: bytes, spec: snapshot.specVersion, transaction: snapshot.transactionVersion)
            let address = Data(repeating: 2, count: 32)
            XCTAssertThrowsError(try runtime.builder(
                dest: address,
                asset: .native(ChainID(snapshot.genesis)),
                amount: 1,
                keepAlive: true,
                context: .init(
                    sender: address,
                    nonce: 0,
                    height: 1,
                    block: "0x" + snapshot.genesis
                )
            )) {
                XCTAssertEqual($0 as? WalletError, .transferRejected(reason))
            }
        }
    }
}
