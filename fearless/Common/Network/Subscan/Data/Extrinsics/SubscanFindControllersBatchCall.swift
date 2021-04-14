import FearlessUtils
import Foundation
import IrohaCrypto

struct SubscanFindControllersBatchCall {
    let controllers: [String]

    init?(callArgs: JSON, chain: Chain) {
        guard let data = callArgs.stringValue?.data(using: .utf8) else { return nil }
        guard let array = try? JSONDecoder().decode([InnerRepresentation]?.self, from: data) else { return nil }
        let controllers = array
            .map(\.value)
            .map { wrappers -> [String] in
                wrappers
                    .filter { $0.call_function == CallFunction.bond.rawValue || $0.call_function == CallFunction.set_controller.rawValue }
                    .map { wraper -> [String] in
                        wraper.call_args
                            .filter { $0.name == "controller" && $0.type == "Address" }
                            .compactMap(\.value)
                            .map(\.accountId)
                    }
                    .flatMap { $0 }
            }
            .flatMap { $0 }

        let addressFactory = SS58AddressFactory()
        let decodedAddresses = controllers
            .compactMap { accountId -> String? in
                guard let accountIdData = try? Data(hexString: accountId) else { return nil }
                return try? addressFactory.addressFromAccountId(
                    data: accountIdData,
                    type: chain.addressType
                )
            }
        self.controllers = decodedAddresses
    }
}

extension SubscanFindControllersBatchCall {
    private struct InnerRepresentation: Decodable {
        let name: String
        let type: String
        let value: [CallArgsWrapper]
    }

    // swiftlint:disable all
    enum CallFunction: String, Decodable {
        case bond
        case set_controller
    }

    private struct CallArgsWrapper: Decodable {
        let call_args: [CallArg]
        let call_function: String
    }

    private struct CallArg: Decodable {
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
    // swiftlint:enable all
}
