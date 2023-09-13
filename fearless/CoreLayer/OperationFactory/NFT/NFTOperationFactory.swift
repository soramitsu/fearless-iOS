import Foundation
import RobinHood
import CommonWallet
import IrohaCrypto
import SSFUtils
import SSFModels
import FearlessKeys

enum BlockExplorerApiKey {
    case etherscan
    case polygonscan

    init?(chainId: String) {
        switch chainId {
        case "1":
            self = .etherscan
        case "137":
            self = .polygonscan
        default:
            return nil
        }
    }

    var value: String {
        switch self {
        case .etherscan:
            return BlockExplorerApiKeys.etherscanApiKey
        case .polygonscan:
            return BlockExplorerApiKeys.polygonscanApiKey
        }
    }
}

protocol NFTOperationFactoryProtocol {
    func fetchNFTs(
        chain: ChainModel,
        address: String
    ) -> CompoundOperationWrapper<[EtherscanNftResponseElement]>
}

final class NFTOperationFactory {
    private func createOperation(
        address: String,
        url: URL,
        chain: ChainModel
    ) -> BaseOperation<EtherscanNftsResponse> {
        var urlComponents = URLComponents(string: url.absoluteString)
        var queryItems = [
            URLQueryItem(name: "module", value: "account"),
            URLQueryItem(name: "action", value: "tokennfttx"),
            URLQueryItem(name: "address", value: address)
        ]

        if let apiKey = BlockExplorerApiKey(chainId: chain.chainId) {
            queryItems.append(URLQueryItem(name: "apikey", value: apiKey.value))
        }

        urlComponents?.queryItems = queryItems

        guard let urlWithParameters = urlComponents?.url else {
            return BaseOperation.createWithError(SubqueryHistoryOperationFactoryError.urlMissing)
        }

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: urlWithParameters)
            request.httpMethod = HttpMethod.get.rawValue

            return request
        }

        let resultFactory = AnyNetworkResultFactory<EtherscanNftsResponse> { data, response, error in
            do {
                if let data = data {
                    let response = try JSONDecoder().decode(
                        EtherscanNftsResponse.self,
                        from: data
                    )

                    return .success(response)
                } else if let error = error {
                    return .failure(error)
                } else {
                    return .failure(SubqueryHistoryOperationFactoryError.incorrectInputData)
                }
            } catch {
                return .failure(error)
            }
        }

        let operation = NetworkOperation(
            requestFactory: requestFactory,
            resultFactory: resultFactory
        )

        return operation
    }

    private func createMapOperation(
        dependingOn remoteOperation: BaseOperation<EtherscanNftsResponse>,
        address: String,
        chain _: ChainModel
    ) -> BaseOperation<[EtherscanNftResponseElement]> {
        ClosureOperation {
            let remoteTransactions = try remoteOperation.extractNoCancellableResultData().result

            print("Remote transactions: ", remoteTransactions)

            let tokenIds = remoteTransactions.compactMap { $0.tokenID }.withoutDuplicates()

            print("Token ids: ", tokenIds)
            var transactions: [EtherscanNftResponseElement] = []
            for tokenId in tokenIds {
                let tokenTransactions = remoteTransactions.filter { $0.tokenID == tokenId }
                let sortedTransactions = tokenTransactions.sorted(by: { element1, element2 in
                    element1.date.compare(element2.date) == .orderedDescending
                })

                print("Token transactions (token ID #\(tokenId): ", sortedTransactions)
                if let transaction = sortedTransactions.first, transaction.to == address {
                    transactions.append(transaction)
                }
            }

            print("11Resulting nfts contains 840919: \(transactions.first(where: { $0.tokenID == "840919" }) != nil)")

            return transactions
        }
    }
}

extension NFTOperationFactory: NFTOperationFactoryProtocol {
    func fetchNFTs(
        chain: ChainModel,
        address: String
    ) -> CompoundOperationWrapper<[EtherscanNftResponseElement]> {
        guard let baseUrl = chain.externalApi?.history?.url else {
            return CompoundOperationWrapper.createWithError(SubqueryHistoryOperationFactoryError.urlMissing)
        }

        let remoteOperation = createOperation(
            address: address,
            url: baseUrl,
            chain: chain
        )

        let mapOperation = createMapOperation(
            dependingOn: remoteOperation,
            address: address,
            chain: chain
        )

        mapOperation.addDependency(remoteOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [remoteOperation])
    }
}
