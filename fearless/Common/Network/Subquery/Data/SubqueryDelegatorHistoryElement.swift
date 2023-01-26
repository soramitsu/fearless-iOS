import Foundation

struct SubqueryDelegatorHistoryElement: Decodable {
    let id: String?
    let delegatorHistoryElements: SubqueryDelegatorHistoryNodes

    init(json: [String: Any]) throws {
        id = json["id"] as? String

        guard let elementsDict = json["delegatorHistoryElements"] as? [String: Any] else {
            throw SubqueryHistoryOperationFactoryError.incorrectInputData
        }

        delegatorHistoryElements = try SubqueryDelegatorHistoryNodes(json: elementsDict)
    }
}
