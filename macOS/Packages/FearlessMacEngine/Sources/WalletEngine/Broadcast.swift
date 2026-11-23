import Foundation
import SSFUtils
import WalletCore

struct TrackingSchedule {
    var evmDeadline: TimeInterval = 1800
    var substrateDeadline: TimeInterval = 900
    var firstDelay: TimeInterval = 1
    var maximumDelay: TimeInterval = 15
}

enum FinalityRead {
    case waiting
    case confirmed(TokenAmount?)
}

extension NetworkServices {
    func pollFinality(until deadline: Date, read: @escaping () async throws -> FinalityRead) async throws -> TokenAmount? {
        let remaining = max(0, deadline.timeIntervalSinceNow)
        let schedule = tracking
        return try await withThrowingTaskGroup(of: TokenAmount?.self) { group in
            group.addTask {
                try await Task.sleep(for: .seconds(remaining))
                throw WalletError.network("Final outcome is unknown. Check the explorer before sending again.")
            }
            group.addTask {
                var delay = schedule.firstDelay
                while true {
                    try Task.checkCancellation()
                    do {
                        if case let .confirmed(fee) = try await read() {
                            return fee
                        }
                    } catch let error as WalletError {
                        if case .transferRejected = error {
                            throw error
                        }
                    } catch is CancellationError { throw CancellationError() }
                    catch { /* A later read may recover before the deadline. */ }
                    try await Task.sleep(for: .seconds(delay))
                    delay = min(delay * 2, schedule.maximumDelay)
                }
            }
            defer { group.cancelAll() }
            return try await group.next() ?? nil
        }
    }

    func receipt(_ item: ActivityItem, chain: Catalog.Network, included: (String) -> Void) async throws -> FinalityRead {
        guard let hash = item.hash,
              let receipt = try await rpc(chain.id, "eth_getTransactionReceipt", [hash]) as? [String: Any],
              (receipt["transactionHash"] as? String)?.lowercased() == hash.lowercased(),
              let block = receipt["blockHash"] as? String, let height = receipt["blockNumber"] as? String else {
            return .waiting
        }
        included(block)
        guard let finalized = try await rpc(chain.id, "eth_getBlockByNumber", ["finalized", false]) as? [String: Any],
              let number = finalized["number"], try Self.quantity(number) >= Self.quantity(height),
              let canonical = try await rpc(chain.id, "eth_getBlockByNumber", [height, false]) as? [String: Any],
              (canonical["hash"] as? String)?.lowercased() == block.lowercased() else { return .waiting }
        switch receipt["status"] as? String {
        case "0x0": throw WalletError.transferRejected("Transaction reverted.")
        case "0x1":
            if let used = receipt["gasUsed"], let price = receipt["effectiveGasPrice"], let decimals = chain.assets.first?.decimals {
                return .confirmed(try? Self.amount(Self.quantity(used) * Self.quantity(price), decimals: decimals))
            }
            return .confirmed(nil)
        default: return .waiting
        }
    }

    func broadcast(
        _ bytes: Data,
        item: ActivityItem,
        chain: Catalog.Network,
        updates: AsyncThrowingStream<TransferProgress, Error>.Continuation,
        accepted: () async -> Void
    ) async throws -> TokenAmount? {
        guard let hash = item.hash else { throw WalletError.storage("Missing transaction hash.") }
        let hex = bytes.toHex(includePrefix: true)
        if chain.evmID != nil {
            do {
                guard let remote = try await rpc(chain.id, "eth_sendRawTransaction", [hex], write: true) as? String,
                      remote.lowercased() == hash else {
                    throw WalletError.network("Unexpected transaction hash. Check the explorer before retrying.")
                }
            } catch let fault as RPCFault {
                let message = fault.message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let known = ["already known", "known transaction", "already imported"]
                guard message == hash || known.contains(message) ||
                    known.contains(where: { message == $0 + ": " + hash || message == $0 + " " + hash }) else {
                    throw WalletError.transferRejected(fault.message)
                }
            }
            await accepted()
            updates.yield(.broadcast(hash: hash, explorerURL: item.explorerURL))
            var previous: String?
            return try await pollFinality(until: Date().addingTimeInterval(tracking.evmDeadline)) {
                try await self.receipt(item, chain: chain) { block in
                    if previous != block {
                        previous = block; updates.yield(.included(blockHash: block))
                    }
                }
            }
        }
        let subscription = try await watch(chain.id, extrinsic: hex)
        defer { Task { await subscription.cancel() } }
        await accepted()
        updates.yield(.broadcast(hash: hash, explorerURL: item.explorerURL))
        let deadline = Date().addingTimeInterval(tracking.substrateDeadline)
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                for try await status in subscription.events {
                    if let value = status as? [String: Any] {
                        if let block = value["inBlock"] as? String {
                            updates.yield(.included(blockHash: block))
                        }
                        if let block = value["finalized"] as? String {
                            _ = try await self.pollFinality(until: deadline) {
                                try await self.confirmDispatch(chain.id, block: block, hash: hash)
                                return .confirmed(nil)
                            }
                            return
                        }
                        if value["usurped"] != nil || value["finalityTimeout"] != nil {
                            throw WalletError.network("The transaction left the watch queue. Check the explorer.")
                        }
                    } else if let status = status as? String {
                        if status == "invalid" {
                            throw WalletError.transferRejected("Node reported invalid transaction.")
                        }
                        if status == "dropped" {
                            throw WalletError.network("Node dropped the transaction from its pool.")
                        }
                    }
                }
                throw WalletError.network("Transaction subscription ended. Check the explorer.")
            }
            group.addTask {
                try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow)))
                throw WalletError.network("Still awaiting finality. Check the explorer.")
            }
            defer { group.cancelAll() }
            try await group.next()
        }
        return nil
    }

    func finalizedBody(_ id: ChainID, block: String) async throws -> (String, [String]) {
        guard let result = try await rpc(id, "chain_getBlock", [block]) as? [String: Any],
              let body = result["block"] as? [String: Any], let header = body["header"] as? [String: Any],
              let parent = header["parentHash"] as? String, let calls = body["extrinsics"] as? [String] else {
            throw WalletError.network("Could not read the finalized block.")
        }
        return (parent, calls)
    }

    func dispatch(_ id: ChainID, block: String, parent: String, index: Int) async throws {
        let rt = try await runtime(id, block: parent)
        let events = try await value(rt, id, block: block, module: "System", name: "Events", keys: [])
        try rt.confirmDispatch(events: events, index: index)
    }

    func confirmDispatch(_ id: ChainID, block: String, hash: String) async throws {
        let (parent, calls) = try await finalizedBody(id, block: block)
        guard let index = try Self.extrinsicIndex(hash, in: calls) else {
            throw WalletError.network("Could not confirm inclusion in the finalized block.")
        }
        try await dispatch(id, block: block, parent: parent, index: index)
    }

    static func extrinsicIndex(_ hash: String, in calls: [String]) throws -> Int? {
        try calls.firstIndex { try Data(hexStringSSF: $0).blake2b32().toHex(includePrefix: true) == hash.lowercased() }
    }
}

extension SubstrateRuntime {
    func confirmDispatch(events: JSON?, index: Int) throws {
        for record in events?.arrayValue ?? [] {
            let phase = record["phase"] ?? record[0]
            let event = record["event"] ?? record[1]
            guard phase?[0]?.stringValue == "ApplyExtrinsic", phase?[1]?.stringValue == String(index) else {
                continue
            }
            let name: String?, dispatchError: JSON?
            if event?[0]?.stringValue == "System" {
                name = event?[1]?[0]?.stringValue
                dispatchError = event?[1]?[1]?["dispatch_error"]
            } else if let pallet = event?[0]?.unsignedIntValue, let variant = event?[1]?.unsignedIntValue,
                      let module = metadata.modules.first(where: { $0.name == "System" && UInt64($0.index) == pallet }),
                      let code = UInt8(exactly: variant) {
                name = try metadata.getEvent(in: module, at: code)?.name
                dispatchError = event?[2]?[0]
            } else {
                continue
            }
            switch name {
            case "ExtrinsicSuccess":
                return
            case "ExtrinsicFailed":
                let reason = [dispatchError?[0]?.stringValue, dispatchError?[1]?[0]?.stringValue]
                    .compactMap { $0 }.joined(separator: ".")
                throw WalletError.transferRejected(reason.isEmpty ? "The runtime reported ExtrinsicFailed." : reason)
            default:
                continue
            }
        }
        throw WalletError.network("Finalized on chain. Dispatch outcome could not be verified.")
    }
}
