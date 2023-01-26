import Foundation

struct SubqueryDelegatorHistoryData: Decodable {
    struct HistoryElements: Decodable {
        let nodes: [SubqueryDelegatorHistoryElement]

        init(json: [String: Any]) throws {
            guard let nodesArray = json["nodes"] as? [[String: Any]] else {
                throw SubqueryHistoryOperationFactoryError.incorrectInputData
            }

            let nodes = try nodesArray.compactMap { nodeJson in
                try SubqueryDelegatorHistoryElement(json: nodeJson)
            }

            self.nodes = nodes
        }
    }

    let delegators: HistoryElements

    init(json: [String: Any]) throws {
        guard let delegatorsDict = json["delegators"] as? [String: Any] else {
            throw SubqueryHistoryOperationFactoryError.incorrectInputData
        }

        delegators = try SubqueryDelegatorHistoryData.HistoryElements(json: delegatorsDict)
    }
}
