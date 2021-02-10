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
            var phishingItems: [PhishingItem] = []

            if let json = try JSONSerialization.jsonObject(with: data,
                                                           options: [.mutableContainers]) as? [String: AnyObject] {
                for (key, value) in json {
                    if let addresses = value as? [String] {
                        for address in addresses {
                            do {
                                let typeRawValue = try SS58AddressFactory().type(fromAddress: address)

                                guard let addressType = SNAddressType(rawValue: typeRawValue.uint8Value) else {
                                    continue
                                }

                                let accountId = try SS58AddressFactory().accountId(fromAddress: address,
                                                                                   type: addressType)

                                let item = PhishingItem(source: key,
                                                        publicKey: accountId.toHex())
                                phishingItems.append(item)
                            }
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
