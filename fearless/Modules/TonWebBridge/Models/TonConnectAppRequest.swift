import Foundation
import TonSwift
import SSFModels

extension TonConnect {
    struct AppRequest: Codable {
        enum Method: String, Codable {
            case sendTransaction
        }
        
        let method: Method
        let params: [SendTransactionParam]
        let id: String
        
        enum CodingKeys: String, CodingKey {
            case method
            case params
            case id
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            method = try container.decode(Method.self, forKey: .method)
            id = try container.decode(String.self, forKey: .id)
            let paramsArray = try container.decode([String].self, forKey: .params)
            let jsonDecoder = JSONDecoder()
            params = paramsArray.compactMap {
                guard let data = $0.data(using: .utf8) else { return nil }
                return try? jsonDecoder.decode(SendTransactionParam.self, from: data)
            }
        }
    }
}
