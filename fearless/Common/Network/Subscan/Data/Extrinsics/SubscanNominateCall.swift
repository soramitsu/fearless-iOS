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
        controllers = decodedAddresses
    }
}

extension SubscanNominateCall {
    private struct InnerRepresentation: Decodable {
        let name: String
        let type: String
        let value: [SubscanExtrinsicsAccountId]
    }
}
