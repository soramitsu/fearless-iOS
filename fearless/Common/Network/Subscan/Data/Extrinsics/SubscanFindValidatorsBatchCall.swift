import FearlessUtils
import Foundation
import IrohaCrypto

struct SubscanFindValidatorsBatchCall {
    let validatorAddresses: [String]

    init?(callArgs: JSON, chain: Chain) {
        guard let data = callArgs.stringValue?.data(using: .utf8) else { return nil }
        guard let array = try? JSONDecoder().decode([InnerRepresentation]?.self, from: data) else { return nil }
        let controllers = array
            .map(\.value)
            .map { wrappers -> [String] in
                wrappers
                    .filter { $0.call_function == .nominate }
                    .map { wraper -> [String] in
                        wraper.call_args
                            .flatMap { $0.value.map(\.accountId) }
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

        validatorAddresses = decodedAddresses
    }
}

extension SubscanFindValidatorsBatchCall {
    private struct InnerRepresentation: Decodable {
        let name: String
        let type: String
        let value: [CallArgsWrapper]
    }

    // swiftlint:disable all
    enum CallFunction: String, Decodable {
        case nominate
        case bond
    }

    private struct CallArgsWrapper: Decodable {
        let call_args: [CallArg]
        let call_function: CallFunction

        enum CodingKeys: String, CodingKey {
            case call_args
            case call_function
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            call_function = try container.decode(CallFunction.self, forKey: .call_function)
            if call_function == .nominate {
                call_args = try container.decode([CallArg].self, forKey: .call_args)
            } else {
                call_args = []
            }
        }
    }

    private struct CallArg: Decodable {
        let name: String
        let value: [SubscanExtrinsicsAccountId]
    }
    // swiftlint:enable all
}
