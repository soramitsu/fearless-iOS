import FearlessUtils
import Foundation
import IrohaCrypto

struct SubscanNominateCall {
    let controllers: [String]

    init?(callArgs: JSON, chain: Chain) {
        guard let data = callArgs.stringValue?.data(using: .utf8) else { return nil }
        guard let array = try? JSONDecoder().decode([InnerRepresentation]?.self, from: data) else { return nil }
        let rawControllerIds = array
            .map(\.value)
            .map { $0.map(\.id) }
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
        controllers = decodedAddresses
    }
}

extension SubscanNominateCall {
    private struct InnerRepresentation: Decodable {
        let name: String
        let type: String
        let value: [TargetId]
    }

    // swiftlint:disable all
    private struct TargetId: Decodable {
        private enum CodingKeys: String, CodingKey {
            case id = "Id"
        }

        let id: String

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let id = try? container.decode(String.self) {
                self.id = id
            } else {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = try container.decode(String.self, forKey: .id)
            }
        }
    }
    // swiftlint:enable all
}
