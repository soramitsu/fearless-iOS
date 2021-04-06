import FearlessUtils
import Foundation
import IrohaCrypto

struct SubscanBondCall {
    let controller: String

    private struct InnerRepresentation: Decodable {
        let name: String
        let type: String
        let value: SubscanExtrinsicsAccountId?

        enum CodingKeys: String, CodingKey {
            case name
            case type
            case value
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            type = try container.decode(String.self, forKey: .type)
            value = try? container.decodeIfPresent(SubscanExtrinsicsAccountId.self, forKey: .value)
        }
    }

    init?(callArgs: JSON, chain: Chain) {
        guard let data = callArgs.stringValue?.data(using: .utf8) else { return nil }
        guard let array = try? JSONDecoder().decode([InnerRepresentation]?.self, from: data) else { return nil }
        guard let controller = array.first(
            where: { $0.name == "controller" && $0.type == "Address" }) else { return nil }
        guard let accountId = controller.value?.accountId else { return nil }
        guard let controllerAddressData = try? Data(hexString: accountId) else { return nil }
        guard let controllerAddress = try? SS58AddressFactory().addressFromAccountId(
            data: controllerAddressData,
            type: chain.addressType
        ) else { return nil }
        self.controller = controllerAddress
    }
}
