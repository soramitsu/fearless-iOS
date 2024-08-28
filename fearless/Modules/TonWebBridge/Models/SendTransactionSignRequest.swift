import Foundation
import TonSwift
import SSFModels

struct SendTransactionSignRequest: Decodable {
    let params: [SendTransactionParam]

    enum CodingKeys: String, CodingKey {
        case params
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var params = [SendTransactionParam]()
        while !container.isAtEnd {
            let param = try container.decode(SendTransactionParam.self)
            params.append(param)
        }
        self.params = params
    }
}
