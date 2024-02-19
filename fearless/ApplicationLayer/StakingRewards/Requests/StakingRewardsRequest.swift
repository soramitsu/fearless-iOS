import Foundation
import SSFUtils
import RobinHood

class StakingRewardsRequest: RequestConfig {
    init(
        baseURL: URL,
        query: String
    ) throws {
        let defaultHeaders = [
            HTTPHeader(
                field: HttpHeaderKey.contentType.rawValue,
                value: HttpContentType.json.rawValue
            )
        ]

        let info = JSON.dictionaryValue(["query": JSON.stringValue(query)])
        let data = try JSONEncoder().encode(info)

        super.init(
            baseURL: baseURL,
            method: .post,
            endpoint: nil,
            headers: defaultHeaders,
            body: data
        )
    }
}
