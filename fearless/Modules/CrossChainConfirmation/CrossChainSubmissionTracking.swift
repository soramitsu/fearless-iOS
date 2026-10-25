import BigInt
import Foundation
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils

/// The stable identity of one cross-chain transfer: wallet, origin account, reviewed route, recipient and amount. It
/// leaves out the fee and the runtime version, so retrying the same transfer after either changed yields the same key.
enum ReviewedCrossChainTransferKey {
    static func make(
        walletId: MetaAccountId,
        originChainId: ChainModel.Id,
        originAccountId: AccountId,
        routeId: String,
        destinationChainId: ChainModel.Id,
        destinationAccountId: AccountId,
        amount: BigUInt
    ) throws -> String {
        try MutationIntentDigest.make([
            "xcm-transfer-v1", walletId, originChainId.lowercased(), originAccountId.toHex(), routeId,
            destinationChainId.lowercased(), destinationAccountId.toHex(), amount.description
        ])
    }
}

/// What the origin chain did with an included submission.
enum ReviewedCrossChainDispatchOutcome: Equatable {
    case succeeded(blockHash: String)
    case failed(blockHash: String)
    /// No inclusion was observed in time, or the block could not be read: the transfer stays in doubt.
    case unknown
}

/// How a submission the node accepted ended for the user.
enum ReviewedCrossChainSubmissionResult: Equatable {
    /// Included and dispatched on the origin chain. The bridge delivers it to the destination later.
    case awaitingBridge(extrinsicHash: String?)
    /// Accepted by the node, but its inclusion was not observed in time.
    case unconfirmed(extrinsicHash: String?)
}

enum ReviewedCrossChainDispatchError: LocalizedError, Equatable {
    /// Included, but the runtime rejected it (`System.ExtrinsicFailed`): nothing was burned, the fee was charged.
    case extrinsicFailed(extrinsicHash: String?)
    /// The transport failed after the extrinsic was handed over, so the node may have accepted it.
    case submissionInDoubt
    /// The record that guards against sending the same transfer twice could not be stored.
    case journalUnavailable

    var errorDescription: String? {
        switch self {
        case .extrinsicFailed:
            return NSLocalizedString(
                "cross_chain.dispatch.failed",
                value: "The origin network included the transfer but rejected it, so nothing was sent to the bridge. Only the network fee was charged.",
                comment: ""
            )
        case .submissionInDoubt:
            return NSLocalizedString(
                "cross_chain.dispatch.in_doubt",
                value: "The network may have received this transfer. Check the origin account's history before sending it again; Fearless asks for confirmation before it sends the same transfer twice.",
                comment: ""
            )
        case .journalUnavailable:
            return NSLocalizedString(
                "cross_chain.dispatch.journal_unavailable",
                value: "Fearless could not record this transfer before sending it, so it was not sent.",
                comment: ""
            )
        }
    }
}

protocol ReviewedCrossChainDispatchWatching {
    func outcome(subscriptionId: String, extrinsicHash: String) async -> ReviewedCrossChainDispatchOutcome
}

/// Follows an `author_submitAndWatchExtrinsic` subscription to the block that includes the extrinsic, finds the
/// extrinsic in that block by hash and reads the block's `System.Events` for its `ExtrinsicSuccess` or `ExtrinsicFailed`.
final class ReviewedCrossChainDispatchWatcher: ReviewedCrossChainDispatchWatching {
    private let connection: JSONRPCEngine
    private let runtime: RuntimeCodingServiceProtocol
    private let timeout: TimeInterval

    init(
        connection: JSONRPCEngine,
        runtime: RuntimeCodingServiceProtocol,
        timeout: TimeInterval = 45
    ) {
        self.connection = connection
        self.runtime = runtime
        self.timeout = timeout
    }

    func outcome(subscriptionId: String, extrinsicHash: String) async -> ReviewedCrossChainDispatchOutcome {
        guard let blockHash = await inclusionBlockHash(subscriptionId: subscriptionId) else {
            return .unknown
        }
        do {
            let block: SignedBlock = try await request(RPCMethod.getChainBlock, params: [blockHash])
            guard let index = Self.index(of: extrinsicHash, in: block.block.extrinsics) else {
                return .unknown
            }
            let records = try await events(at: blockHash)
            return Self.outcome(of: records, extrinsicIndex: UInt32(index), blockHash: blockHash)
        } catch {
            return .unknown
        }
    }

    static func index(of extrinsicHash: String, in extrinsics: [String]) -> Int? {
        let expected = extrinsicHash.lowercased()
        return extrinsics.firstIndex { extrinsic in
            (try? Data(hexStringSSF: extrinsic).blake2b32().toHex(includePrefix: true).lowercased()) == expected
        }
    }

    static func outcome(
        of records: [EventRecord],
        extrinsicIndex: UInt32,
        blockHash: String
    ) -> ReviewedCrossChainDispatchOutcome {
        let own = records.filter { $0.extrinsicIndex == extrinsicIndex && $0.event.section == "System" }
        if own.contains(where: { $0.event.method == "ExtrinsicFailed" }) {
            return .failed(blockHash: blockHash)
        }
        if own.contains(where: { $0.event.method == "ExtrinsicSuccess" }) {
            return .succeeded(blockHash: blockHash)
        }
        return .unknown
    }

    /// Decodes a block's raw `System.Events` with the origin runtime, as the storage queries do.
    static func decodeEvents(_ data: Data, factory: RuntimeCoderFactoryProtocol) throws -> [EventRecord] {
        try ReviewedSystemEventsDecoder()
            .decode(data: data, path: .events, codingFactory: factory)
            .map(to: [EventRecord].self)
    }

    private func inclusionBlockHash(subscriptionId: String) async -> String? {
        await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            let requestId = connection.generateRequestId()
            let resolution = ReviewedOneShotResolution(continuation) { [connection] in
                connection.cancelForIdentifier(requestId)
            }
            let subscription = JSONRPCSubscription<JSONRPCSubscriptionUpdate<ExtrinsicStatus>>(
                requestId: requestId,
                requestData: Data(),
                requestOptions: JSONRPCOptions(resendOnReconnect: false),
                updateClosure: { update in
                    switch update.params.result {
                    case let .inBlock(blockHash), let .finalized(blockHash):
                        resolution.resolve(blockHash)
                    case .ready, .broadcast:
                        break
                    }
                },
                failureClosure: { _, unsubscribed in
                    if unsubscribed {
                        resolution.resolve(nil)
                    }
                }
            )
            subscription.remoteId = subscriptionId
            connection.addSubscription(subscription)
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                resolution.resolve(nil)
            }
        }
    }

    private func request<T: Decodable>(_ method: String, params: [String]) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            do {
                _ = try connection.callMethod(method, params: params) { (result: Result<T, Error>) in
                    continuation.resume(with: result)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func events(at blockHash: String) async throws -> [EventRecord] {
        let key = try StorageKeyFactory().createStorageKey(
            moduleName: StorageCodingPath.events.moduleName,
            storageName: StorageCodingPath.events.itemName
        )
        let raw: String? = try await request(RPCMethod.getStorage, params: [key.toHex(includePrefix: true), blockHash])
        guard let raw else {
            throw BaseOperationError.unexpectedDependentResult
        }
        let factory = try await runtime.fetchCoderFactory()
        return try Self.decodeEvents(try Data(hexStringSSF: raw), factory: factory)
    }
}

private struct ReviewedSystemEventsDecoder: StorageDecodable {}

/// Resumes a continuation exactly once, whichever of the subscription, its failure or the timeout comes first. The lock
/// makes it safe to share across those threads.
private final class ReviewedOneShotResolution: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<String?, Never>?
    private let onResolve: () -> Void

    init(_ continuation: CheckedContinuation<String?, Never>, onResolve: @escaping () -> Void) {
        self.continuation = continuation
        self.onResolve = onResolve
    }

    func resolve(_ value: String?) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        guard let pending else { return }
        onResolve()
        pending.resume(returning: value)
    }
}

/// A cross-chain transfer the wallet handed to the network without learning that it failed. While one exists, the same
/// transfer is only sent again after the user confirms, because a second burn cannot be undone.
struct ReviewedCrossChainSubmissionRecord: Codable, Equatable {
    enum Status: String, Codable {
        /// About to be handed over; written before the extrinsic leaves the app.
        case submitting
        /// The node may have accepted it, but no outcome was observed.
        case inDoubt
        /// Included and dispatched on the origin chain; the bridge delivers it later.
        case awaitingBridge
    }

    let transferKey: String
    let intentSha256: String
    var status: Status
    var extrinsicHash: String?
    var blockHash: String?
    let summary: String
    let createdAt: Date
    var updatedAt: Date
}

protocol ReviewedCrossChainSubmissionJournaling: AnyObject {
    func unresolved(for transferKey: String, now: Date) -> ReviewedCrossChainSubmissionRecord?
    func save(_ record: ReviewedCrossChainSubmissionRecord) throws
    func remove(transferKey: String)
}

/// `UserDefaults` keeps the records across restarts, so a transfer interrupted by a crash or a kill between hand-over
/// and the node's reply is still known on the next launch. Records hold public data only: hashes, the transfer key and
/// a display summary.
final class ReviewedCrossChainSubmissionJournal: ReviewedCrossChainSubmissionJournaling {
    static let shared = ReviewedCrossChainSubmissionJournal()

    /// After a day the bridge has delivered the transfer or the user has had its hash long enough to check it.
    static let confirmationWindow: TimeInterval = 24 * 60 * 60

    private static let key = "cross_chain.submission_journal.v1"
    private static let unreadableKey = "cross_chain.submission_journal.v1.unreadable"
    private static let lock = NSLock()

    private let userDefaults: UserDefaults
    private let logger: LoggerProtocol?

    init(userDefaults: UserDefaults = .standard, logger: LoggerProtocol? = Logger.shared) {
        self.userDefaults = userDefaults
        self.logger = logger
    }

    func unresolved(for transferKey: String, now: Date) -> ReviewedCrossChainSubmissionRecord? {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        guard let record = loadLocked()[transferKey] else { return nil }
        return now.timeIntervalSince(record.createdAt) < Self.confirmationWindow ? record : nil
    }

    func save(_ record: ReviewedCrossChainSubmissionRecord) throws {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        var records = loadLocked().filter {
            record.updatedAt.timeIntervalSince($0.value.createdAt) < Self.confirmationWindow
        }
        records[record.transferKey] = record
        try storeLocked(records)
    }

    func remove(transferKey: String) {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        var records = loadLocked()
        guard records.removeValue(forKey: transferKey) != nil else { return }
        try? storeLocked(records)
    }

    private func loadLocked() -> [String: ReviewedCrossChainSubmissionRecord] {
        guard let data = userDefaults.data(forKey: Self.key) else { return [:] }
        do {
            return try Self.decoder.decode([String: ReviewedCrossChainSubmissionRecord].self, from: data)
        } catch {
            // Only this class writes the key. Keep damaged bytes for diagnosis instead of letting them hide every
            // record, and start over.
            userDefaults.set(data, forKey: Self.unreadableKey)
            userDefaults.removeObject(forKey: Self.key)
            logger?.error("Unreadable cross-chain submission journal was set aside: \(error)")
            return [:]
        }
    }

    private func storeLocked(_ records: [String: ReviewedCrossChainSubmissionRecord]) throws {
        let data = try Self.encoder.encode(records)
        userDefaults.set(data, forKey: Self.key)
        guard userDefaults.data(forKey: Self.key) == data else {
            throw ReviewedCrossChainDispatchError.journalUnavailable
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()
}
