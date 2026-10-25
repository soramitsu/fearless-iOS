import Foundation
import XCTest
@testable import SSFStorageQueryKit

final class CachedStorageStreamTests: XCTestCase {
    private enum Failure: Error, Equatable {
        case cache
        case remote
    }

    func testCacheFailureStillFetchesRemoteOnAll() async throws {
        let stream: AsyncThrowingStream<CachedStorageResponse<String>, Error> = CachedStorageStream.make(
            options: .onAll,
            readCache: { _ in throw Failure.cache },
            fetchRemote: { "fresh" }
        )
        let values = try await collect(stream)
        XCTAssertEqual(values.map(\.value), ["fresh"])
        XCTAssertEqual(values.map(\.type), [.remote])
    }

    func testCacheOnlyFailureTerminatesWithItsError() async {
        let stream: AsyncThrowingStream<CachedStorageResponse<String>, Error> = CachedStorageStream.make(
            options: .onCache,
            readCache: { _ in throw Failure.cache },
            fetchRemote: { XCTFail("Cache-only must not perform a remote request"); return nil }
        )
        do {
            _ = try await collect(stream)
            XCTFail("Expected cache error")
        } catch {
            XCTAssertEqual(error as? Failure, .cache)
        }
    }

    func testRemoteErrorTerminatesAfterTheCachedValue() async {
        let stream: AsyncThrowingStream<CachedStorageResponse<String>, Error> = CachedStorageStream.make(
            options: .onAll,
            readCache: { $0.yield(CachedStorageResponse(value: "cached", type: .cache)) },
            fetchRemote: { throw Failure.remote }
        )
        var values: [String?] = []
        do {
            for try await response in stream {
                values.append(response.value)
            }
            XCTFail("Expected remote error")
        } catch {
            XCTAssertEqual(error as? Failure, .remote)
        }
        XCTAssertEqual(values, ["cached"])
    }

    func testRemoteErrorWinsAfterCacheFailure() async {
        let stream: AsyncThrowingStream<CachedStorageResponse<String>, Error> = CachedStorageStream.make(
            options: .onAll,
            readCache: { _ in throw Failure.cache },
            fetchRemote: { throw Failure.remote }
        )
        do {
            _ = try await collect(stream)
            XCTFail("Expected remote error")
        } catch {
            XCTAssertEqual(error as? Failure, .remote)
        }
    }

    func testEmptyOptionsPreserveCacheThenRemoteOrder() async throws {
        let stream: AsyncThrowingStream<CachedStorageResponse<String>, Error> = CachedStorageStream.make(
            options: [],
            readCache: { $0.yield(CachedStorageResponse(value: "cached", type: .cache)) },
            fetchRemote: { "fresh" }
        )
        let values = try await collect(stream)
        XCTAssertEqual(values.map(\.value), ["cached", "fresh"])
        XCTAssertEqual(values.map(\.type), [.cache, .remote])
    }

    func testCacheCancellationDoesNotStartRemoteFallback() async {
        let stream: AsyncThrowingStream<CachedStorageResponse<String>, Error> = CachedStorageStream.make(
            options: .onAll,
            readCache: { _ in throw CancellationError() },
            fetchRemote: { XCTFail("Cancellation is not a cache miss"); return nil }
        )
        do {
            _ = try await collect(stream)
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testConsumerCancellationCancelsRemoteProducer() async {
        let started = expectation(description: "Remote producer started")
        let cancelled = expectation(description: "Remote producer cancelled")
        let stream: AsyncThrowingStream<CachedStorageResponse<String>, Error> = CachedStorageStream.make(
            options: .onPerform,
            readCache: { _ in XCTFail("Remote-only must not read the cache") },
            fetchRemote: {
                started.fulfill()
                do {
                    try await Task.sleep(nanoseconds: 30_000_000_000)
                } catch {
                    XCTAssertTrue(error is CancellationError)
                    cancelled.fulfill()
                    throw error
                }
                XCTFail("Producer should have been cancelled")
                return nil
            }
        )
        let consumer = Task {
            do { for try await _ in stream {} } catch {}
        }
        await fulfillment(of: [started], timeout: 2)
        consumer.cancel()
        await fulfillment(of: [cancelled], timeout: 2)
    }

    private func collect<T>(
        _ stream: AsyncThrowingStream<CachedStorageResponse<T>, Error>
    ) async throws -> [CachedStorageResponse<T>] {
        var values: [CachedStorageResponse<T>] = []
        for try await value in stream {
            values.append(value)
        }
        return values
    }
}

final class StorageCacheKeyTests: XCTestCase {
    func testNamespacingSeparatesChainsAndPreservesRawKey() {
        let key = Data([0, 1, 255, 4])
        let first = StorageCacheKey.encode(remoteKey: key, chainId: "chain/a")
        let second = StorageCacheKey.encode(remoteKey: key, chainId: "chain/ab")
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(StorageCacheKey.remoteKey(from: first, chainId: "chain/a"), key)
        XCTAssertNil(StorageCacheKey.remoteKey(from: first, chainId: "chain/ab"))
    }

    func testPrefixQueryMatchesOnlyTheSameChainAndRetainsFullRemoteKey() {
        let prefix = Data([0, 1])
        let key = prefix + Data([255, 4])
        let stored = StorageCacheKey.encode(remoteKey: key, chainId: "a")
        XCTAssertTrue(stored.hasPrefix(StorageCacheKey.encode(remoteKey: prefix, chainId: "a")))
        XCTAssertFalse(stored.hasPrefix(StorageCacheKey.encode(remoteKey: prefix, chainId: "ab")))
        XCTAssertEqual(StorageCacheKey.remoteKey(from: stored, chainId: "a"), key)
    }

    func testLegacyAndMalformedRowsAreNotGuessedToBelongToAChain() {
        XCTAssertNil(StorageCacheKey.remoteKey(from: "0001ff04", chainId: "a"))
        let prefix = StorageCacheKey.encode(remoteKey: Data(), chainId: "a")
        for suffix in ["", "f", "zz", "00/11", "00 11"] {
            XCTAssertNil(StorageCacheKey.remoteKey(from: prefix + suffix, chainId: "a"))
        }
    }
}
