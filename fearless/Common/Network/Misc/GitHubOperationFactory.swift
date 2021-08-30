import Foundation
import RobinHood
import IrohaCrypto

protocol GitHubOperationFactoryProtocol {
    func fetchPhishingListOperation(_ url: URL) -> NetworkOperation<[PhishingItem]>
}

class GitHubOperationFactory: GitHubOperationFactoryProtocol {
    func fetchPhishingListOperation(_ url: URL) -> NetworkOperation<[PhishingItem]> {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<[PhishingItem]> { data in
            guard let json =
                try JSONSerialization.jsonObject(
                    with: data,
                    options: [.mutableContainers]
                ) as? [String: AnyObject]
            else {
                return []
            }

            let addressFactory = SS58AddressFactory()

            let phishingItems = json.flatMap { (key, value) -> [PhishingItem] in
                if let publicKeys = value as? [String] {
                    let items = publicKeys.compactMap {
                        self.getPublicKey(from: $0, using: addressFactory)
                    }.map {
                        PhishingItem(source: key, publicKey: $0)
                    }
                    return items
                }
                return []
            }

            return phishingItems
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }

    private func getPublicKey(from address: String, using addressFactory: SS58AddressFactoryProtocol) -> String? {
        do {
            let typeRawValue = try addressFactory.type(fromAddress: address)

            guard let addressType = SNAddressType(rawValue: typeRawValue.uint8Value) else {
                return nil
            }

            let publicKey = try addressFactory.accountId(
                fromAddress: address,
                type: addressType
            )

            return publicKey.toHex()
        } catch {
            return nil
        }
    }
}
