import Foundation

struct SubqueryPageInfo: Decodable {
    let startCursor: String?
    let endCursor: String?

    func toContext() -> [String: String]? {
        if startCursor == nil, endCursor == nil {
            return nil
        }
        var context: [String: String] = [:]
        if let startCursor = startCursor {
            context["startCursor"] = startCursor
        }

        if let endCursor = endCursor {
            context["endCursor"] = endCursor
        }

        return context
    }
}
