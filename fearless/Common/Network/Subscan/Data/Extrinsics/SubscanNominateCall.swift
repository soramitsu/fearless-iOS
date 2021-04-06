import FearlessUtils
import Foundation
import IrohaCrypto

struct SubscanNominateCall {
    let validatorAddresses: [String]

    init?(callArgs: JSON, chain: Chain) {
        guard let data = callArgs.stringValue?.data(using: .utf8) else { return nil }
        guard let array = try? JSONDecoder().decode([InnerRepresentation]?.self, from: data) else { return nil }
        let rawControllerIds = array
            .map(\.value)
            .map { $0.map(\.accountId) }
            .flatMap { $0 }

        let addressFactory = SS58AddressFactory()
        let decodedAddresses = rawControllerIds
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

extension SubscanNominateCall {
    private struct InnerRepresentation: Decodable {
        let value: [SubscanExtrinsicsAccountId]

        enum CodingKeys: String, CodingKey {
            case value
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            value = (try? container.decodeIfPresent([SubscanExtrinsicsAccountId].self, forKey: .value)) ?? []
        }
    }
}
