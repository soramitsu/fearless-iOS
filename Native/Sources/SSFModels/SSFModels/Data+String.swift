import Foundation

private enum JsonDataError: Error {
    case invalidConversionToString
}

public extension Data {
    func toJsonString() throws -> String {
        let jsonObject = try JSONSerialization.jsonObject(with: self)
        let jsonData = try JSONSerialization.data(
            withJSONObject: jsonObject,
            options: [.prettyPrinted]
        )

        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw JsonDataError.invalidConversionToString
        }

        return jsonString
    }
}
