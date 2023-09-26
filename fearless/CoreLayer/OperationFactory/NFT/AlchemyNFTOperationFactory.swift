import Foundation
import SSFModels
import RobinHood
import FearlessKeys

enum AlchemyNFTOperationFactoryError: Error {
    case chainUnsupported(name: String)
}

final class AlchemyNFTOperationFactory {
    // MARK: Collections

    private func createFetchCollectionsOperation(
        address: String,
        url: URL
    ) -> BaseOperation<AlchemyNftCollectionsResponse> {
        let authorizedUrl = url.appendingPathComponent(ThirdPartyServicesApiKeysDebug.alchemyApiKey)
        let endpointUrl = authorizedUrl.appendingPathComponent("getContractsForOwner")
        var urlComponents = URLComponents(string: endpointUrl.absoluteString)
        urlComponents?.queryItems = [URLQueryItem(name: "owner", value: address)]

        guard let urlWithParameters = urlComponents?.url else {
            return BaseOperation.createWithError(SubqueryHistoryOperationFactoryError.urlMissing)
        }

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: urlWithParameters)
            request.httpMethod = HttpMethod.get.rawValue

            return request
        }

        let resultFactory = AnyNetworkResultFactory<AlchemyNftCollectionsResponse> { data, response, error in
            do {
                if let data = data {
                    let response = try JSONDecoder().decode(
                        AlchemyNftCollectionsResponse.self,
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

    private func createMapCollectionsOperation(
        dependingOn remoteOperation: BaseOperation<AlchemyNftCollectionsResponse>,
        chain: ChainModel
    ) -> BaseOperation<[NFTCollection]?> {
        ClosureOperation {
            let remoteTransactions = try remoteOperation.extractNoCancellableResultData().contracts
            return remoteTransactions?.compactMap {
                let media = $0.media?.compactMap {
                    NFTMedia(
                        thumbnail: $0.thumbnail,
                        mediaPath: $0.raw,
                        format: $0.format
                    )
                }

                return NFTCollection(
                    address: $0.address,
                    numberOfTokens: $0.numDistinctTokensOwned,
                    isSpam: $0.isSpam,
                    title: $0.title,
                    name: $0.name,
                    creator: $0.contractDeployer,
                    price: $0.openSea?.floorPrice,
                    media: media,
                    tokenType: $0.tokenType,
                    desc: $0.openSea?.description,
                    opensea: $0.openSea,
                    chain: chain
                )
            }
        }
    }

    // MARK: Nfts

    private func createFetchNftsOperation(
        address: String,
        url: URL
    ) -> BaseOperation<AlchemyNftsResponse> {
        let authorizedUrl = url.appendingPathComponent(ThirdPartyServicesApiKeysDebug.alchemyApiKey)
        let endpointUrl = authorizedUrl.appendingPathComponent("getNFTs")
        var urlComponents = URLComponents(string: endpointUrl.absoluteString)
        urlComponents?.queryItems = [
            URLQueryItem(name: "owner", value: address),
            URLQueryItem(name: "excludeFilters[]", value: "spam")
        ]

        guard let urlWithParameters = urlComponents?.url else {
            return BaseOperation.createWithError(SubqueryHistoryOperationFactoryError.urlMissing)
        }

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: urlWithParameters)
            request.httpMethod = HttpMethod.get.rawValue

            return request
        }

        let resultFactory = AnyNetworkResultFactory<AlchemyNftsResponse> { data, response, error in
            do {
                if let data = data {
                    let response = try JSONDecoder().decode(
                        AlchemyNftsResponse.self,
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

    private func createMapNftsOperation(
        dependingOn remoteOperation: BaseOperation<AlchemyNftsResponse>,
        chain: ChainModel
    ) -> BaseOperation<[NFT]?> {
        ClosureOperation {
            let remoteTransactions = try remoteOperation.extractNoCancellableResultData().ownedNfts
            return remoteTransactions?.compactMap {
                let media = $0.media?.compactMap {
                    NFTMedia(
                        thumbnail: $0.thumbnail,
                        mediaPath: $0.raw,
                        format: $0.format
                    )
                }

                let collection = NFTCollection(
                    address: $0.contractMetadata?.address,
                    numberOfTokens: $0.contractMetadata?.numDistinctTokensOwned,
                    isSpam: $0.contractMetadata?.isSpam,
                    title: $0.contractMetadata?.title,
                    name: $0.contractMetadata?.name,
                    creator: $0.contractMetadata?.contractDeployer,
                    price: $0.contractMetadata?.openSea?.floorPrice,
                    media: media,
                    tokenType: $0.contractMetadata?.tokenType,
                    desc: $0.contractMetadata?.openSea?.description,
                    opensea: $0.contractMetadata?.openSea,
                    chain: chain
                )

                return NFT(
                    chain: chain,
                    tokenId: $0.id?.tokenId,
                    title: $0.title,
                    description: $0.description,
                    smartContract: $0.contract?.address,
                    metadata: nil,
                    mediaThumbnail: $0.metadata?.poster ?? $0.media?.first?.thumbnail,
                    media: media,
                    tokenType: $0.id?.tokenMetadata?.tokenType,
                    collectionName: $0.contractMetadata?.name,
                    collection: collection
                )
            }
        }
    }
}

extension AlchemyNFTOperationFactory: NFTOperationFactoryProtocol {
    func fetchNFTs(chain: SSFModels.ChainModel, address: String) -> RobinHood.CompoundOperationWrapper<[NFT]?> {
        guard
            let ethereumChain = EthereumChain(rawValue: chain.chainId),
            let identifier = ethereumChain.alchemyChainIdentifier,
            let url = URL(string: "https://\(identifier).g.alchemy.com/nft/v2/")
        else {
            return CompoundOperationWrapper.createWithError(AlchemyNFTOperationFactoryError.chainUnsupported(name: chain.name))
        }

        let fetchOperation = createFetchNftsOperation(
            address: address,
            url: url
        )

        let mapOperation = createMapNftsOperation(dependingOn: fetchOperation, chain: chain)
        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchOperation])
    }

    func fetchCollections(chain: ChainModel, address: String) -> CompoundOperationWrapper<[NFTCollection]?> {
        guard
            let ethereumChain = EthereumChain(rawValue: chain.chainId),
            let identifier = ethereumChain.alchemyChainIdentifier,
            let url = URL(string: "https://\(identifier).g.alchemy.com/nft/v2/")
        else {
            return CompoundOperationWrapper.createWithError(AlchemyNFTOperationFactoryError.chainUnsupported(name: chain.name))
        }

        let fetchOperation = createFetchCollectionsOperation(
            address: address,
            url: url
        )

        let mapOperation = createMapCollectionsOperation(dependingOn: fetchOperation, chain: chain)
        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchOperation])
    }
}
