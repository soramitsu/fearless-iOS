import Foundation
import SSFUtils
import WalletCore
import XCTest
@testable import WalletEngine

private struct AssetRestrictionFixture: Decodable {
    struct Row: Decodable {
        let module, name, stableAccount, stableKey: String
        let stableAssetID: UInt32
        let stableValue: String?
        let positive: Restriction
    }

    struct Restriction: Decodable {
        let key, value, account, balance: String
        let assetID: UInt32
    }

    struct Entry: Decodable {
        let key, value: String
    }

    let specVersion, transactionVersion: UInt32
    let rows: [Row]
    let restricted: [String: Entry]
}

final class AssetBalanceTests: XCTestCase {
    func testBalanceDeadlineReturnsWhileAnotherCallerStillAwaitsTheSharedLoad() async throws {
        let (gate, release) = AsyncStream<Funds>.makeStream()
        let shared = Task {
            var iterator = gate.makeAsyncIterator()
            guard let value = await iterator.next() else { throw CancellationError() }
            return value
        }
        let otherCaller = Task {
            try await NetworkServices.boundedFunds(timeout: .seconds(60)) { try await shared.value }
        }
        let timedOut = expectation(description: "Return while the shared load remains suspended")
        let waiter = Task {
            defer { timedOut.fulfill() }
            do {
                _ = try await NetworkServices.boundedFunds(timeout: .zero) { try await shared.value }
                XCTFail("Expected a balance timeout")
            } catch {
                XCTAssertEqual(error as? WalletError, .network("Balance request timed out."))
            }
        }
        // The expectation also bounds the test if a structured join regresses.
        await fulfillment(of: [timedOut], timeout: 10)
        release.yield(Funds(free: 7, total: 7, transferable: 7, minimum: 0, exists: true))
        release.finish()
        await waiter.value
        let otherResult = try await otherCaller.value
        XCTAssertEqual(otherResult.free, 7)
    }

    func testAssetHubFreezerAndHolderAgainstRecordedStorage() throws {
        let bundle = Bundle.module
        let fixtureURL = try XCTUnwrap(bundle.url(forResource: "asset-restrictions", withExtension: "json"))
        let fixture = try JSONDecoder().decode(AssetRestrictionFixture.self, from: Data(contentsOf: fixtureURL))
        let metadataURL = try XCTUnwrap(bundle.url(forResource: "asset-hub.scale", withExtension: "deflate"))
        let metadata = try NSData(contentsOf: metadataURL).decompressed(using: .zlib) as Data
        let runtime = try SubstrateRuntime(
            data: metadata,
            spec: fixture.specVersion,
            transaction: fixture.transactionVersion
        )
        func assetKey(_ assetID: UInt32) -> Data {
            withUnsafeBytes(of: assetID.littleEndian) { Data($0) }
        }

        var amounts: [String: JSON] = [:]
        for row in fixture.rows {
            let keys = try [assetKey(row.stableAssetID), Data(hexStringSSF: row.stableAccount)]
            XCTAssertEqual(try runtime.storage(row.module, row.name, keys: keys).key, row.stableKey)
            XCTAssertNil(row.stableValue)
            let sample = row.positive
            let restricted = try [assetKey(sample.assetID), Data(hexStringSSF: sample.account)]
            let storage = try runtime.storage(row.module, row.name, keys: restricted)
            XCTAssertEqual(storage.key, sample.key)
            let value = try runtime.decode(Data(hexStringSSF: sample.value), type: storage.type)
            XCTAssertEqual(value.stringValue, sample.balance)
            amounts[row.module] = value
        }

        let sample = try XCTUnwrap(fixture.rows.first?.positive)
        let keys = try [assetKey(sample.assetID), Data(hexStringSSF: sample.account)]
        func read(_ name: String, keys: [Data]) throws -> JSON {
            let saved = try XCTUnwrap(fixture.restricted[name.lowercased()])
            let path = try runtime.storage("Assets", name, keys: keys)
            XCTAssertEqual(path.key, saved.key)
            return try runtime.decode(Data(hexStringSSF: saved.value), type: path.type)
        }
        let actual = try Funds.asset(
            read("Account", keys: keys), details: read("Asset", keys: [keys[0]]),
            frozen: XCTUnwrap(amounts["AssetsFreezer"]), held: XCTUnwrap(amounts["AssetsHolder"])
        )
        XCTAssertEqual(actual.free, 10_000_000)
        XCTAssertEqual(actual.total, 3_468_590_000)
        XCTAssertEqual(actual.transferable, 0)
    }

    func testPalletAssetsReducibleBalanceWithFreezeHoldAndStatus() throws {
        func funds(
            frozen: String? = nil,
            held: String? = nil,
            status: String = "Liquid",
            assetStatus: String = "Live",
            supply: String = "500"
        ) throws -> Funds {
            let holder = JSON.dictionaryValue(["balance": .stringValue("100"),
                                               "status": .arrayValue([.stringValue(status), .null])])
            let details = JSON.dictionaryValue(["min_balance": .stringValue("10"), "supply": .stringValue(supply),
                                                "status": .arrayValue([.stringValue(assetStatus), .null])])
            return try Funds.asset(
                holder,
                details: details,
                frozen: frozen.map(JSON.stringValue),
                held: held.map(JSON.stringValue)
            )
        }

        XCTAssertEqual(try funds().transferable, 100)
        XCTAssertEqual(try funds().preserved, 90)
        XCTAssertEqual(try funds(frozen: "0").transferable, 90)
        XCTAssertEqual(try funds(held: "35").total, 135)
        XCTAssertEqual(try funds(held: "35").transferable, 90)
        XCTAssertEqual(try funds(frozen: "70", held: "30").transferable, 60)
        XCTAssertEqual(try funds(frozen: "120").transferable, 0)
        XCTAssertEqual(try funds(status: "Frozen").transferable, 0)
        XCTAssertEqual(try funds(status: "Blocked").transferable, 0)
        XCTAssertEqual(try funds(assetStatus: "Destroying").transferable, 0)
        XCTAssertEqual(try funds(supply: "20").transferable, 20)
    }
}
