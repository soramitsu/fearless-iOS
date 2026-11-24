import Foundation
import Observation
import WalletCore

/// The nodes of one network: pick one or leave it automatic, add a custom
/// node (the engine checks it answers for the right network), remove one.
@MainActor
@Observable
final class NodesModel {
    @ObservationIgnored private let nodeService: any NodeServicing
    @ObservationIgnored private var generation = 0

    private(set) var chain: Chain?
    private(set) var nodes: [ChainNode] = []
    /// Nil means automatic selection.
    private(set) var selectedNodeID: String?
    private(set) var isLoading = false

    var isAddingNode = false
    var newNodeName = ""
    var newNodeURL = ""
    private(set) var isChecking = false
    private(set) var addError: String?

    init(nodeService: any NodeServicing) {
        self.nodeService = nodeService
    }

    func load(_ chain: Chain?) async {
        generation += 1
        let current = generation
        self.chain = chain
        cancelAdd()
        guard let chain else {
            nodes = []
            selectedNodeID = nil
            return
        }
        isLoading = true
        let loaded = await nodeService.nodes(for: chain.id)
        let selected = await nodeService.selectedNode(for: chain.id)
        guard current == generation else { return }
        nodes = loaded
        selectedNodeID = selected?.id
        isLoading = false
    }

    func select(_ nodeID: String?) async {
        guard let chain else { return }
        let node = nodes.first { $0.id == nodeID }
        selectedNodeID = node?.id
        await nodeService.selectNode(node, for: chain.id)
    }

    /// Why the typed address cannot be used, before asking the engine.
    var urlProblem: String? {
        let text = newNodeURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let chain else { return nil }
        guard let url = URL(string: text), let scheme = url.scheme?.lowercased(), let host = url.host, !host.isEmpty else {
            return "Enter a full address such as \(Self.example(for: chain))."
        }
        let allowed = Self.allowedSchemes(for: chain)
        guard allowed.contains(scheme) else {
            return "\(chain.name) nodes use \(allowed.map { $0 + "://" }.joined(separator: " or "))."
        }
        if nodes.contains(where: { $0.url.absoluteString == url.absoluteString }) {
            return "This node is already in the list."
        }
        return nil
    }

    nonisolated static func allowedSchemes(for chain: Chain) -> [String] {
        chain.ecosystem == .substrate ? ["wss", "ws"] : ["https", "http", "wss", "ws"]
    }

    nonisolated static func example(for chain: Chain) -> String {
        chain.ecosystem == .substrate ? "wss://node.example.org" : "https://node.example.org"
    }

    var canAdd: Bool {
        !newNodeURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && urlProblem == nil && !isChecking
    }

    func beginAdd() {
        newNodeName = ""
        newNodeURL = ""
        addError = nil
        isAddingNode = true
    }

    func cancelAdd() {
        isAddingNode = false
        newNodeName = ""
        newNodeURL = ""
        addError = nil
    }

    func addNode() async {
        guard canAdd, let chain, let url = URL(string: newNodeURL.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        isChecking = true
        addError = nil
        defer { isChecking = false }
        do {
            let node = try await nodeService.addCustomNode(
                name: newNodeName.trimmingCharacters(in: .whitespacesAndNewlines),
                url: url,
                for: chain.id
            )
            nodes = await nodeService.nodes(for: chain.id)
            if !nodes.contains(where: { $0.id == node.id }) { nodes.append(node) }
            cancelAdd()
        } catch {
            addError = ErrorText.message(for: error)
        }
    }

    func remove(_ node: ChainNode) async {
        guard let chain, node.isCustom else { return }
        await nodeService.removeCustomNode(node, for: chain.id)
        nodes = await nodeService.nodes(for: chain.id)
        selectedNodeID = await nodeService.selectedNode(for: chain.id)?.id
    }
}
