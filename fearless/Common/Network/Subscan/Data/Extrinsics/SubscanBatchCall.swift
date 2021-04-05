import FearlessUtils
import Foundation
import IrohaCrypto

struct SubscanBatchCall {
    let controllers: [String]

    init?(callArgs: JSON, chain: Chain) {
        guard let data = callArgs.stringValue?.data(using: .utf8) else { return nil }
        guard let array = try? JSONDecoder().decode([InnerRepresentation]?.self, from: data) else { return nil }
        let controllers = array
            .map(\.value)
            .map { wrappers -> [String] in
                wrappers
                    .filter { $0.call_function == .bond }
                    .map { wraper -> [String] in
                        wraper.call_args
                            .filter { $0.name == "controller" && $0.type == "Address" }
                            .map(\.value_raw)
                            .map { $0.dropFirst(2) }
                            .map { String($0) }
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

extension SubscanBatchCall {
    private struct InnerRepresentation: Decodable {
        let name: String
        let type: String
        let value: [CallArgsWrapper]
    }

    enum CallFunction: String, Decodable {
        case bond
        case nominate
    }

    // swiftlint:disable identifier_name
    private struct CallArgsWrapper: Decodable {
        let call_args: [CallArg]
        let call_function: CallFunction
    }

    private struct CallArg: Decodable {
        let name: String
        let type: String
        let value_raw: String
    }
    // swiftlint:enable identifier_name
}
