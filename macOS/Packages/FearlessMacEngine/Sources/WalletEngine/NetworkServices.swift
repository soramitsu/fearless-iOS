import Foundation
import WalletCore

struct NodePreferences: Codable {
    var custom: [String: [ChainNode]] = [:]
    var selected: [String: URL] = [:]
}

extension EngineStore {
    func preferences() -> NodePreferences {
        (try? files.read(NodePreferences.self, "nodes.json")) ?? NodePreferences()
    }

    func editPreferences(_ edit: (inout NodePreferences) -> Void) throws {
        var value = try files.read(NodePreferences.self, "nodes.json") ?? NodePreferences()
        edit(&value)
        try files.write(value, "nodes.json")
    }
}

struct SubmissionNotSent: Error {
    let reason: WalletError
}

actor NetworkServices: NodeServicing {
    let store: EngineStore
    let session: URLSession
    let tracking: TrackingSchedule
    private var sockets: [ChainID: RPCSocket] = [:]
    private var verified: [ChainID: [URL: Date]] = [:]
    private var coolingDown: [ChainID: [URL: Date]] = [:]
    var reviewedFees: [TransferRequest: FeeReview] = [:]
    var priceCache: [String: AssetPrice] = [:]
    var runtimes: [ChainID: SubstrateRuntime] = [:]
    var loading: [ChainID: (UInt64, Task<SubstrateRuntime, Error>)] = [:]

    init(store: EngineStore, session: URLSession, tracking: TrackingSchedule = .init()) {
        self.tracking = tracking
        self.store = store; self.session = session
    }

    func nodes(for chainID: ChainID) async -> [ChainNode] {
        guard let network = try? Catalog.chain(chainID) else { return [] }
        return network.nodes + (await store.preferences().custom[chainID.rawValue] ?? [])
    }

    func selectedNode(for chainID: ChainID) async -> ChainNode? {
        let url = await store.preferences().selected[chainID.rawValue]
        return await nodes(for: chainID).first { $0.url == url }
    }

    func selectNode(_ node: ChainNode?, for chainID: ChainID) async {
        if let node, !(await nodes(for: chainID)).contains(node) {
            return
        }
        try? await store.editPreferences { $0.selected[chainID.rawValue] = node?.url }
        await sockets.removeValue(forKey: chainID)?.close()
    }

    func addCustomNode(name: String, url: URL, for chainID: ChainID) async throws -> ChainNode {
        let chain = try Catalog.chain(chainID)
        guard ["wss", "https"].contains(url.scheme?.lowercased()), url.host != nil, url.user == nil,
              url.password == nil else { throw WalletError.network("Enter a secure RPC endpoint for this network.") }
        try await check(url, chain, isolated: true)
        if let existing = await nodes(for: chainID).first(where: { $0.url == url }) {
            return existing
        }
        let node = ChainNode(name: name, url: url, isCustom: true)
        try await store.editPreferences {
            if !($0.custom[chainID.rawValue] ?? []).contains(where: { $0.url == url }) {
                $0.custom[chainID.rawValue, default: []].append(node)
            }
        }
        return node
    }

    func removeCustomNode(_ node: ChainNode, for chainID: ChainID) async {
        guard node.isCustom else { return }
        try? await store.editPreferences {
            $0.custom[chainID.rawValue]?.removeAll { $0.url == node.url }
            if $0.selected[chainID.rawValue] == node.url {
                $0.selected[chainID.rawValue] = nil
            }
        }
        await sockets.removeValue(forKey: chainID)?.close()
    }

    private func ordered(_ id: ChainID) async -> [ChainNode] {
        let all = await nodes(for: id)
        let selected = await selectedNode(for: id)
        if let selected {
            return [selected]
        }
        let priority = all
        let cooling = coolingDown[id] ?? [:]
        return priority.filter { (cooling[$0.url] ?? .distantPast) < Date() } +
            priority.filter { (cooling[$0.url] ?? .distantPast) >= Date() }
    }

    func socket(_ url: URL, _ chain: ChainID, forWatch: Bool = false) async -> RPCSocket {
        if forWatch {
            return RPCSocket(url: url, session: session)
        }
        if let existing = sockets[chain], existing.url == url {
            return existing
        }
        let old = sockets[chain]
        let next = RPCSocket(url: url, session: session)
        sockets[chain] = next
        await old?.close()
        return next
    }

    private func call(
        _ url: URL,
        _ chain: ChainID,
        _ method: String,
        _ params: [Any],
        _ timeout: TimeInterval
    ) async throws -> Any {
        if url.scheme == "wss" {
            return try await socket(url, chain).request(method, params, timeout: timeout)
        }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0",
            "id": 1,
            "method": method,
            "params": params
        ])
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse,
              let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any], obj["id"] as? Int == 1 else {
            throw WalletError.network("Invalid response from the RPC endpoint.")
        }
        if obj["error"] != nil {
            throw RPCFault.error(in: obj)
        }
        guard (200 ..< 300).contains(http.statusCode), let result = obj["result"] else {
            throw WalletError.network("Invalid response from the RPC endpoint.")
        }
        return result
    }

    private func check(_ url: URL, _ chain: Catalog.Network, isolated: Bool = false) async throws {
        let evm = chain.evmID != nil
        let method = evm ? "eth_chainId" : "chain_getBlockHash"
        let params: [Any] = evm ? [] : [0]
        let value: Any
        if isolated, url.scheme == "wss" {
            // Probing a candidate must leave an active transfer subscription on the selected node intact.
            let probe = RPCSocket(url: url, session: session)
            defer { Task { await probe.close() } }
            value = try await probe.request(method, params, timeout: 6)
        } else {
            value = try await call(url, chain.id, method, params, 6)
        }
        let expected = chain.evmID.map { "0x" + String($0, radix: 16) } ?? ("0x" + chain.id.rawValue)
        guard (value as? String)?.lowercased() == expected
        else { throw WalletError.network("Endpoint belongs to a different network.") }
    }

    func rpc(_ id: ChainID, _ method: String, _ params: [Any] = [], write: Bool = false) async throws -> Any {
        let chain = try Catalog.chain(id)
        let deadline = Date().addingTimeInterval(15)
        var endpoints = await ordered(id)
        // HTTPS supports compression for the large metadata response. Keep multiplexed
        // WebSockets for interactive calls and honor an explicitly selected endpoint.
        if method == "state_getMetadata", await selectedNode(for: id) == nil {
            endpoints = endpoints.filter { $0.url.scheme == "https" } + endpoints.filter { $0.url.scheme != "https" }
        }
        for (index, node) in endpoints.enumerated() {
            try Task.checkCancellation()
            guard deadline.timeIntervalSinceNow > 0 else { break }
            var startedRequest = false
            do {
                if write || (verified[id]?[node.url] ?? .distantPast) < Date() {
                    try await check(node.url, chain)
                    verified[id, default: [:]][node.url] = Date().addingTimeInterval(60)
                }
                startedRequest = true
                return try await call(
                    node.url,
                    id,
                    method,
                    params,
                    min(
                        deadline.timeIntervalSinceNow,
                        index == endpoints.count - 1 || method == "state_getMetadata" ? 15 : 6
                    )
                )
            } catch is CancellationError { throw CancellationError() }
            catch let error as URLError where error.code == .cancelled { throw CancellationError() }
            catch let fault as RPCFault where startedRequest {
                if write, method == "eth_sendRawTransaction" {
                    throw fault
                }
                throw WalletError.network(fault.message)
            } catch {
                try Task.checkCancellation()
                verified[id]?[node.url] = nil
                coolingDown[id, default: [:]][node.url] = Date().addingTimeInterval(30)
                if endpoints.count == 1, !write {
                    throw WalletError.network("RPC at \(node.url.host ?? chain.name) failed.")
                }
                if write, startedRequest {
                    throw WalletError.network("Submission status unknown. Check activity before retrying.")
                }
            }
        }
        let error = WalletError.network("No responding node for \(chain.name).")
        if write {
            throw SubmissionNotSent(reason: error)
        }
        throw error
    }

    func watch(_ id: ChainID, extrinsic: String) async throws -> RPCSocket.Subscription {
        _ = try Catalog.chain(id)
        let endpoints = await ordered(id)
        if endpoints.count == 1, endpoints.first?.url.scheme != "wss" {
            throw SubmissionNotSent(reason: .network("Select a secure WebSocket node to submit on this network."))
        }
        for node in endpoints where node.url.scheme == "wss" {
            let dedicated = await socket(node.url, id, forWatch: true)
            do { try await dedicated.verifyGenesis(id) }
            catch is CancellationError { await dedicated.close(); throw CancellationError() }
            catch { await dedicated.close(); try Task.checkCancellation(); continue }
            do { return try await dedicated.watch(extrinsic) }
            catch is CancellationError { await dedicated.close(); throw CancellationError() }
            catch let fault as RPCFault { await dedicated.close(); throw WalletError.transferRejected(fault.message) }
            catch { await dedicated.close(); try Task.checkCancellation(); throw WalletError.network("Submission status unknown. Check activity before retrying.") }
        }
        throw SubmissionNotSent(reason: .network("No responding WebSocket endpoint."))
    }
}
