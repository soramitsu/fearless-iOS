import Foundation

struct SubqueryDelegatorHistoryNodes: Decodable {
    let nodes: [SubqueryDelegatorHistoryItem]

    init(json: [String: Any]) throws {
        guard let nodesArray = json["nodes"] as? [[String: Any]] else {
            throw SubqueryHistoryOperationFactoryError.incorrectInputData
        }

        let nodes = try nodesArray.compactMap { nodeJson in
            try SubqueryDelegatorHistoryItem(json: nodeJson)
        }

        self.nodes = nodes
    }
}
