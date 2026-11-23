import Foundation
import SSFUtils
import WalletCore
import XCTest
@testable import WalletEngine

final class DispatchTests: XCTestCase {
    func testDispatchOutcomesAgainstFinalizedAssetHubBlock() throws {
        struct Recording: Decodable {
            let spec, transaction: UInt32
            let storageKey, storageValue: String
        }
        let bundle = Bundle.module
        let recordingURL = try XCTUnwrap(bundle.url(forResource: "dispatch", withExtension: "json"))
        let recording = try JSONDecoder().decode(Recording.self, from: Data(contentsOf: recordingURL))
        let metadataURL = try XCTUnwrap(bundle.url(forResource: "asset-hub.scale", withExtension: "deflate"))
        let metadata = try NSData(contentsOf: metadataURL).decompressed(using: .zlib) as Data
        let runtime = try SubstrateRuntime(data: metadata, spec: recording.spec, transaction: recording.transaction)
        let storage = try runtime.storage("System", "Events", keys: [])
        XCTAssertEqual(storage.key, recording.storageKey)
        let events = try runtime.decode(Data(hexStringSSF: recording.storageValue), type: storage.type)
        XCTAssertEqual(events.arrayValue?.count, 8)

        // Polkadot.js decoded both inherent extrinsics successfully and found Token.Frozen at index 2.
        XCTAssertNoThrow(try runtime.confirmDispatch(events: events, index: 0))
        XCTAssertNoThrow(try runtime.confirmDispatch(events: events, index: 1))
        XCTAssertThrowsError(try runtime.confirmDispatch(events: events, index: 2)) {
            XCTAssertEqual($0 as? WalletError, .transferRejected("Token.Frozen"))
        }
        XCTAssertThrowsError(try runtime.confirmDispatch(events: events, index: 3)) {
            guard case .network = $0 as? WalletError else { return XCTFail("Expected an unverified dispatch outcome") }
        }
    }
}
