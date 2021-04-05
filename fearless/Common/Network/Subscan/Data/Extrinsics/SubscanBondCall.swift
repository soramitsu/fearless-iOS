import FearlessUtils
import Foundation
import IrohaCrypto

struct SubscanBondCall {
    let controller: String

    private struct InnerRepresentation: Decodable {
        let name: String
        let type: String
        let value: SubscanExtrinsicsAccountId
    }

    init?(callArgs: JSON, chain: Chain) {
        guard let data = callArgs.stringValue?.data(using: .utf8) else { return nil }
        guard let array = try? JSONDecoder().decode([InnerRepresentation]?.self, from: data) else { return nil }
        guard let controller = array.first(
            where: { $0.name == "controller" && $0.type == "Address" }) else { return nil }
        guard let controllerAddressData = try? Data(hexString: controller.value.accountId) else { return nil }
        guard let controllerAddress = try? SS58AddressFactory().addressFromAccountId(
            data: controllerAddressData,
            type: chain.addressType
        ) else { return nil }
        self.controller = controllerAddress
    }
}
