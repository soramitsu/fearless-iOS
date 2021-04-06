import Foundation

struct SubscanExtrinsicsAccountId: Decodable {
    let accountId: String

    private enum CodingKeys: String, CodingKey {
        case accountId = "Id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let accountId = try? container.decode(String.self) {
            self.accountId = accountId
        } else {
            // Multiaddress
            let container = try decoder.container(keyedBy: CodingKeys.self)
            accountId = try container.decode(String.self, forKey: .accountId)
        }
    }
}
