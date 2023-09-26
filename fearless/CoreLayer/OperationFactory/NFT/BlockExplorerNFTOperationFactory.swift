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
    case bscscan

    init?(chainId: String) {
        switch chainId {
        case "1":
            self = .etherscan
        case "137":
            self = .polygonscan
        case "56", "97":
            self = .bscscan
        default:
            return nil
        }
    }

    var value: String {
        switch self {
        case .etherscan:
            #if DEBUG
                return BlockExplorerApiKeysDebug.etherscanApiKey
            #else
                return BlockExplorerApiKeys.etherscanApiKey
            #endif
        case .polygonscan:
            #if DEBUG
                return BlockExplorerApiKeysDebug.polygonscanApiKey
            #else
                return BlockExplorerApiKeys.polygonscanApiKey
            #endif
        case .bscscan:
            #if DEBUG
                return BlockExplorerApiKeysDebug.bscscanApiKey
            #else
                return BlockExplorerApiKeys.bscscanApiKey
            #endif
        }
    }
}

final class BlockExplorerNFTOperationFactory {
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
            let tokenIds = remoteTransactions?.compactMap { $0.tokenID }.withoutDuplicates().compactMap { $0 } ?? []
            var transactions: [EtherscanNftResponseElement] = []
            for tokenId in tokenIds {
                let tokenTransactions = remoteTransactions?.filter { $0.tokenID == tokenId }
                let sortedTransactions = tokenTransactions?.sorted(by: { element1, element2 in
                    element1.date.compare(element2.date) == .orderedDescending
                })

                if let transaction = sortedTransactions?.first, transaction.to == address {
                    transactions.append(transaction)
                }
            }

            return transactions
        }
    }
}

extension BlockExplorerNFTOperationFactory: NFTOperationFactoryProtocol {
    func fetchNFTs(chain _: ChainModel, address _: String) -> RobinHood.CompoundOperationWrapper<[NFT]?> {
        CompoundOperationWrapper.createWithResult([])
    }

    func fetchCollections(chain _: ChainModel, address _: String) -> RobinHood.CompoundOperationWrapper<[NFTCollection]?> {
        CompoundOperationWrapper.createWithResult([])
    }

    func fetchCollections(chain _: ChainModel, address _: String) -> CompoundOperationWrapper<[NFTCollection]> {
        CompoundOperationWrapper.createWithResult([])
    }

    func fetchNFTs(
        for _: String,
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
