import Foundation

final class AlchemyRequest: RequestConfig {
    private enum Constants {
        static let baseURL = URL(string: "https://eth-mainnet.g.alchemy.com/v2/hkF1wbbTz0G2lKoqb4R09OwkcVl6uGqp")!
        static let httpHeaders = [
            HTTPHeader(field: "accept", value: "application/json"),
            HTTPHeader(field: "content-type", value: "application/json")
        ]
    }

    init(body: Data?) {
        super.init(
            baseURL: Constants.baseURL,
            method: .post,
            endpoint: nil,
            headers: Constants.httpHeaders,
            body: body
        )
    }
}
