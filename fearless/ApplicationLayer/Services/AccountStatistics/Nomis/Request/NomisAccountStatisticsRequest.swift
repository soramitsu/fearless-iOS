import Foundation
import SSFNetwork
import RobinHood
import SSFModels

public class NomisAccountStatisticsRequest: RequestConfig {
    private let address: String

    public init(
        baseURL: URL,
        address: String,
        endpoint: String
    ) throws {
        self.address = address

        let finalEndpoint = [address, endpoint].joined(separator: "/")

        super.init(
            baseURL: baseURL,
            method: .get,
            endpoint: finalEndpoint,
            headers: nil,
            body: nil
        )
    }

    override public var cacheKey: String {
        if let endpoint = endpoint {
            return endpoint + address
        }

        return address
    }
}
