import Foundation
import RobinHood
import IrohaCrypto

protocol GitHubOperationFactoryProtocol {
    func fetchPhishingListOperation(_ url: URL) -> BaseOperation<[PhishingItem]>
}

class GitHubOperationFactory: GitHubOperationFactoryProtocol {
    func fetchPhishingListOperation(_ url: URL) -> BaseOperation<[PhishingItem]> {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.setValue(HttpContentType.json.rawValue,
                             forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<[PhishingItem]> { data in
            guard let json =
                    try JSONSerialization.jsonObject(with: data,
                                                     options: [.mutableContainers]) as? [String: AnyObject]
            else {
                return []
            }

            print(json.compactMap { ($0, $1) })
            print(json.compactMap { $1 })
            var phishingItems: [PhishingItem] = []

            let addressFactory = SS58AddressFactory()
            for (key, value) in json {
                if let addresses = value as? [String] {
                    for address in addresses {
                        do {
                            let typeRawValue = try addressFactory.type(fromAddress: address)

                            guard let addressType = SNAddressType(rawValue: typeRawValue.uint8Value) else {
                                continue
                            }

                            let accountId = try addressFactory.accountId(fromAddress: address,
                                                                         type: addressType)

                            let item = PhishingItem(source: key,
                                                    publicKey: accountId.toHex())
                            phishingItems.append(item)
                        }
                    }
                }
            }
            return phishingItems
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }
}
