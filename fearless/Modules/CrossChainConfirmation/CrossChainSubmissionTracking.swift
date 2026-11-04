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
    /// The runtime rejected the extrinsic in a block the chain has finalized.
    case failed(blockHash: String)
    /// No inclusion was observed in time, the block could not be read, or a failure was seen only in a block the chain
    /// had not finalized: the transfer stays in doubt.
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
    /// The records of recent transfers could not be read, so an earlier attempt of this transfer may be hidden.
    case journalUnreadable

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
        case .journalUnreadable:
            return NSLocalizedString(
                "cross_chain.dispatch.journal_unreadable",
                value: "Fearless cannot read its record of recent cross-chain transfers, so it cannot tell whether "
                    + "this one was already sent. Nothing was sent. Check the origin account's history. New "
                    + "cross-chain transfers are possible again 24 hours after the record became unreadable.",
                comment: ""
            )
        }
    }
}

protocol ReviewedCrossChainDispatchWatching {
    func outcome(subscriptionId: String, extrinsicHash: String) async -> ReviewedCrossChainDispatchOutcome
}

/// The block an extrinsic was included in, and whether the chain had finalized that block when it was read.
struct ReviewedCrossChainInclusion: Equatable {
    let blockHash: String
    let isFinalized: Bool
}

/// Follows an `author_submitAndWatchExtrinsic` subscription until the chain finalizes the block that includes the
/// extrinsic, finds the extrinsic in that block by hash and reads the block's `System.Events` for its
/// `ExtrinsicSuccess` or `ExtrinsicFailed`. Without finality in time it reads the latest best block that included it
/// instead, where only a success counts.
final class ReviewedCrossChainDispatchWatcher: ReviewedCrossChainDispatchWatching {
    private let connection: JSONRPCEngine
    private let runtime: RuntimeCodingServiceProtocol
    private let timeout: TimeInterval

    init(
        connection: JSONRPCEngine,
        runtime: RuntimeCodingServiceProtocol,
        timeout: TimeInterval = 60
    ) {
        self.connection = connection
        self.runtime = runtime
        self.timeout = timeout
    }

    func outcome(subscriptionId: String, extrinsicHash: String) async -> ReviewedCrossChainDispatchOutcome {
        guard let inclusion = await inclusion(subscriptionId: subscriptionId) else {
            return .unknown
        }
        do {
            let block: SignedBlock = try await request(RPCMethod.getChainBlock, params: [inclusion.blockHash])
            guard let index = Self.index(of: extrinsicHash, in: block.block.extrinsics) else {
                return .unknown
            }
            let records = try await events(at: inclusion.blockHash)
            return Self.settled(
                Self.outcome(of: records, extrinsicIndex: UInt32(index), blockHash: inclusion.blockHash),
                isFinalized: inclusion.isFinalized
            )
        } catch {
            return .unknown
        }
    }

    /// A failure read from a block the chain has not finalized proves nothing: the block can be retracted and the same
    /// signed extrinsic included again in another block, where it may succeed. Only a finalized failure is final.
    static func settled(
        _ outcome: ReviewedCrossChainDispatchOutcome,
        isFinalized: Bool
    ) -> ReviewedCrossChainDispatchOutcome {
        if case .failed = outcome, !isFinalized {
            return .unknown
        }
        return outcome
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

    private func inclusion(subscriptionId: String) async -> ReviewedCrossChainInclusion? {
        await withCheckedContinuation { (continuation: CheckedContinuation<ReviewedCrossChainInclusion?, Never>) in
            let requestId = connection.generateRequestId()
            let resolution = ReviewedInclusionResolution(continuation) { [connection] in
                connection.cancelForIdentifier(requestId)
            }
            let subscription = JSONRPCSubscription<JSONRPCSubscriptionUpdate<ExtrinsicStatus>>(
                requestId: requestId,
                requestData: Data(),
                requestOptions: JSONRPCOptions(resendOnReconnect: false),
                updateClosure: { update in
                    switch update.params.result {
                    case let .inBlock(blockHash):
                        // A best block can still be retracted; keep waiting for the finalized one.
                        resolution.include(blockHash)
                    case let .finalized(blockHash):
                        resolution.finalize(blockHash)
                    case .ready, .broadcast:
                        break
                    }
                },
                failureClosure: { _, unsubscribed in
                    if unsubscribed {
                        resolution.end()
                    }
                }
            )
            subscription.remoteId = subscriptionId
            connection.addSubscription(subscription)
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                resolution.end()
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

/// Resumes a continuation exactly once, whichever of finality, the subscription's end or the timeout comes first. The
/// last two answer with the latest best block that included the extrinsic, if any. The lock makes it safe to share
/// across those threads.
private final class ReviewedInclusionResolution: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<ReviewedCrossChainInclusion?, Never>?
    private var bestBlockHash: String?
    private let onResolve: () -> Void

    init(_ continuation: CheckedContinuation<ReviewedCrossChainInclusion?, Never>, onResolve: @escaping () -> Void) {
        self.continuation = continuation
        self.onResolve = onResolve
    }

    func include(_ blockHash: String) {
        lock.lock()
        bestBlockHash = blockHash
        lock.unlock()
    }

    func finalize(_ blockHash: String) {
        resolve(ReviewedCrossChainInclusion(blockHash: blockHash, isFinalized: true))
    }

    func end() {
        lock.lock()
        let blockHash = bestBlockHash
        lock.unlock()
        resolve(blockHash.map { ReviewedCrossChainInclusion(blockHash: $0, isFinalized: false) })
    }

    private func resolve(_ value: ReviewedCrossChainInclusion?) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        guard let pending else { return }
        onResolve()
        pending.resume(returning: value)
    }
}

/// One attempt at a cross-chain transfer that the wallet handed to the network without learning that it failed. While
/// one exists, the same transfer is only sent again after the user confirms, because a second burn cannot be undone.
/// Each attempt keeps its own record: a later attempt that fails never clears an earlier one that may have gone
/// through.
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
    /// Tells this attempt apart from earlier attempts of the same transfer, so settling it never removes their records.
    /// Records written before attempts were kept apart have none and stand for their whole transfer.
    let attemptId: String?
    let intentSha256: String
    var status: Status
    var extrinsicHash: String?
    var blockHash: String?
    let summary: String
    let createdAt: Date
    var updatedAt: Date

    var journalKey: String {
        attemptId.map { "\(transferKey)#\($0)" } ?? transferKey
    }
}

protocol ReviewedCrossChainSubmissionJournaling: AnyObject {
    /// Every attempt of the transfer whose outcome is still unresolved, newest first. Throws while recent records
    /// cannot be read, because one of them may be an attempt of this transfer.
    func unresolved(for transferKey: String, now: Date) throws -> [ReviewedCrossChainSubmissionRecord]
    func save(_ record: ReviewedCrossChainSubmissionRecord) throws
    /// Drops one attempt. Earlier attempts of the same transfer stay and keep asking before it is sent again.
    func remove(_ record: ReviewedCrossChainSubmissionRecord)
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
    private static let unreadableSinceKey = "cross_chain.submission_journal.v1.unreadable_since"
    private static let lock = NSLock()

    private let userDefaults: UserDefaults
    private let logger: LoggerProtocol?

    init(userDefaults: UserDefaults = .standard, logger: LoggerProtocol? = Logger.shared) {
        self.userDefaults = userDefaults
        self.logger = logger
    }

    func unresolved(for transferKey: String, now: Date) throws -> [ReviewedCrossChainSubmissionRecord] {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        return try loadLocked(now: now).values
            .filter { $0.transferKey == transferKey && now.timeIntervalSince($0.createdAt) < Self.confirmationWindow }
            .sorted { ($0.createdAt, $0.journalKey) > ($1.createdAt, $1.journalKey) }
    }

    func save(_ record: ReviewedCrossChainSubmissionRecord) throws {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        var records = try loadLocked(now: record.updatedAt).filter {
            record.updatedAt.timeIntervalSince($0.value.createdAt) < Self.confirmationWindow
        }
        records[record.journalKey] = record
        try storeLocked(records)
    }

    func remove(_ record: ReviewedCrossChainSubmissionRecord) {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        guard var records = try? loadLocked(now: record.updatedAt),
              records.removeValue(forKey: record.journalKey) != nil else { return }
        try? storeLocked(records)
    }

    private func loadLocked(now: Date) throws -> [String: ReviewedCrossChainSubmissionRecord] {
        try checkUnreadableLocked(now: now)
        guard let data = userDefaults.data(forKey: Self.key) else { return [:] }
        do {
            return try Self.decoder.decode([String: ReviewedCrossChainSubmissionRecord].self, from: data)
        } catch {
            // Only this class writes the key. Keep the damaged bytes for diagnosis and remember when they were found.
            userDefaults.set(data, forKey: Self.unreadableKey)
            userDefaults.set(now, forKey: Self.unreadableSinceKey)
            userDefaults.removeObject(forKey: Self.key)
            logger?.error("Unreadable cross-chain submission journal was set aside: \(error)")
            throw ReviewedCrossChainDispatchError.journalUnreadable
        }
    }

    /// Damaged records may hold an attempt that is still on its way, so nothing new is sent until one confirmation
    /// window has passed since they were found. By then none of them could still stand in the way, and they are
    /// dropped.
    private func checkUnreadableLocked(now: Date) throws {
        guard userDefaults.data(forKey: Self.unreadableKey) != nil else { return }
        guard let since = userDefaults.object(forKey: Self.unreadableSinceKey) as? Date, since <= now else {
            // Set aside without a time, or the clock went back: the window starts now.
            userDefaults.set(now, forKey: Self.unreadableSinceKey)
            throw ReviewedCrossChainDispatchError.journalUnreadable
        }
        guard now.timeIntervalSince(since) >= Self.confirmationWindow else {
            throw ReviewedCrossChainDispatchError.journalUnreadable
        }
        userDefaults.removeObject(forKey: Self.unreadableKey)
        userDefaults.removeObject(forKey: Self.unreadableSinceKey)
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
