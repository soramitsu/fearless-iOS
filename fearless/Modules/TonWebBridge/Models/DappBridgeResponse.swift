import Foundation

struct DappBridgeResponse {
    enum Status: String {
        case fulfilled
        case rejected
    }

    enum Data {
        case data(String)
        case error(Int)
    }

    let invocationId: String
    let status: Status
    let data: Data

    var json: String? {
        var dictionary: [String: Any] = [
            "invocationId": invocationId,
            "status": status.rawValue,
            "type": "functionResponse"
        ]
        switch data {
        case let .data(data):
            dictionary["data"] = data
        case let .error(error):
            dictionary["data"] = error
        }
        guard
            let data = try? JSONSerialization.data(withJSONObject: dictionary),
            let dataString = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return dataString
    }
}
