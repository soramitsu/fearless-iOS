import Foundation
import RobinHood
import SSFNetwork
import SSFModels
import Web3
import Web3ContractABI

enum NFTFetchingServiceError: Error {
    case emptyResponse
}

protocol NFTFetchingServiceProtocol {
    func fetchNfts(for wallet: MetaAccountModel) async throws -> [NFT]
    func fetchNftsHistory(for wallet: MetaAccountModel) async throws -> [NFTHistoryObject]
    func fetchNfts(for history: [NFTHistoryObject]) async throws -> [NFT]
}

final class NFTFetchingService {
    private let chainRegistry: ChainRegistryProtocol
    private let nftOperationFactory: NFTOperationFactoryProtocol
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let operationQueue: OperationQueue
    private let networkOperationFactory: NetworkOperationFactoryProtocol
    private let logger: LoggerProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        nftOperationFactory: NFTOperationFactoryProtocol,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue,
        networkOperationFactory: NetworkOperationFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.nftOperationFactory = nftOperationFactory
        self.chainRepository = chainRepository
        self.operationQueue = operationQueue
        self.networkOperationFactory = networkOperationFactory
        self.logger = logger
    }

    private func fetchSupportedChains() async throws -> [ChainModel] {
        try await withCheckedThrowingContinuation { continuation in
            let fetchChainsOperation = chainRepository.fetchAllOperation(with: RepositoryFetchOptions())

            fetchChainsOperation.completionBlock = {
                do {
                    let chains = try fetchChainsOperation.extractNoCancellableResultData()
                    let filteredChains = chains.filter { $0.supportsNft }
                    return continuation.resume(with: .success(filteredChains))
                } catch {
                    return continuation.resume(with: .failure(error))
                }
            }

            operationQueue.addOperation(fetchChainsOperation)
        }
    }

    private func fetchERC721Tokens(for chain: ChainModel, wallet: MetaAccountModel) async throws -> [EtherscanNftResponseElement] {
        guard let address = wallet.fetch(for: chain.accountRequest())?.toAddress() else {
            throw SS58AddressFactoryError.unexpectedAddress
        }

        return try await withCheckedThrowingContinuation { continuation in
            let fetchNftsOperation = nftOperationFactory.fetchNFTs(chain: chain, address: address)

            fetchNftsOperation.targetOperation.completionBlock = {
                do {
                    let nfts = try fetchNftsOperation.targetOperation.extractNoCancellableResultData()
                    continuation.resume(with: .success(nfts))
                } catch {
                    continuation.resume(with: .failure(error))
                }
            }

            operationQueue.addOperations(fetchNftsOperation.allOperations, waitUntilFinished: true)
        }
    }

    private func fetchMetadataUrl(token: EtherscanNftResponseElement, chain: ChainModel) async throws -> URL {
        guard let ws = chainRegistry.getEthereumConnection(for: chain.chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        let contractAddress = try EthereumAddress(hex: token.contractAddress, eip55: false)
        let contract = ws.Contract(type: GenericERC721Contract.self, address: contractAddress)

        guard let tokenId = BigUInt(string: token.tokenID) else {
            throw ConvenienceError(error: "fetchMetadataUrl: incorrect token id: \(token.tokenID)")
        }

        return try await withCheckedThrowingContinuation { continuation in
            contract.tokenURI(tokenId: tokenId).call { response, error in
                if let uri = response?["_tokenURI"] as? String, let url = URL(string: uri) {
                    return continuation.resume(with: .success(url))
                } else if let error = error {
                    return continuation.resume(with: .failure(error))
                } else {
                    return continuation.resume(with: .failure(NFTFetchingServiceError.emptyResponse))
                }
            }
        }
    }

    private func fetchNftMetadata(url: URL) async throws -> NFTMetadata {
        try await withCheckedThrowingContinuation { continuation in
            let fetchMetadataOperation: BaseOperation<NFTMetadata> = networkOperationFactory.fetchData(from: url)

            fetchMetadataOperation.completionBlock = {
                do {
                    let metadata = try fetchMetadataOperation.extractNoCancellableResultData()
                    return continuation.resume(with: .success(metadata))
                } catch {
                    return continuation.resume(with: .failure(error))
                }
            }

            operationQueue.addOperation(fetchMetadataOperation)
        }
    }
}

extension NFTFetchingService: NFTFetchingServiceProtocol {
    func fetchNftsHistory(for wallet: MetaAccountModel) async throws -> [NFTHistoryObject] {
        guard let chains = try? await fetchSupportedChains() else {
            return []
        }

        let history = try await withThrowingTaskGroup(of: [NFTHistoryObject]?.self) { [weak self] group in
            guard let strongSelf = self else {
                return [NFTHistoryObject]()
            }

            for chain in chains {
                group.addTask {
                    if let tokens = try? await strongSelf.fetchERC721Tokens(for: chain, wallet: wallet) {
                        let mappedObjects = tokens.compactMap { NFTHistoryObject(chain: chain, metadata: $0) }
                        print("Received history count: ", mappedObjects.count)
                        print("12Resulting nfts contains 840919: \(mappedObjects.first(where: { $0.metadata.tokenID == "840919" }) != nil)")

                        return mappedObjects
                    } else {
                        return []
                    }
                }
            }

            var result: [NFTHistoryObject] = []

            for try await tokens in group {
                if let tokens = tokens {
                    result.append(contentsOf: tokens)
                }
            }

            return result
        }

        print("13Resulting nfts contains 840919: \(history.first(where: { $0.metadata.tokenID == "840919" }) != nil)")

        print("Resulting history count: ", history.count)
        return history
    }

    func fetchNfts(for history: [NFTHistoryObject]) async throws -> [NFT] {
        let nfts = try await withThrowingTaskGroup(of: NFT?.self) { [weak self] group in
            guard let strongSelf = self else {
                return [NFT]()
            }
            print("14Resulting nfts contains 840919: \(history.first(where: { $0.metadata.tokenID == "840919" }) != nil)")

            for historyObject in history {
                group.addTask {
                    if let url = try? await strongSelf.fetchMetadataUrl(token: historyObject.metadata, chain: historyObject.chain), url.isTLSScheme {
                        if historyObject.metadata.tokenID == "840919" {
                            print("CRAZYSNAKE URL: ", url)
                        }
                        if let metadata = try? await strongSelf.fetchNftMetadata(url: url) {
                            let nft = NFT(chain: historyObject.chain, tokenId: historyObject.metadata.tokenID, tokenName: historyObject.metadata.tokenName, smartContract: historyObject.metadata.contractAddress, metadata: metadata)
                            return nft
                        }

                        print("Failed to fetch metadata TOKEN ID \(historyObject.metadata.tokenID)")

                        let nft = NFT(chain: historyObject.chain, tokenId: historyObject.metadata.tokenID, tokenName: historyObject.metadata.tokenName, smartContract: historyObject.metadata.contractAddress, metadata: nil)
                        return nft
                    } else {
                        print("NO TLS SCHEME TOKEN ID \(historyObject.metadata.tokenID)")

                        let nft = NFT(chain: historyObject.chain, tokenId: historyObject.metadata.tokenID, tokenName: historyObject.metadata.tokenName, smartContract: historyObject.metadata.contractAddress, metadata: nil)
                        return nft
                    }
                }
            }

            var result: [NFT] = []

            for try await nft in group {
                if let nft = nft {
                    result.append(nft)
                }
            }

            return result
        }

        return nfts
    }

    func fetchNfts(for wallet: MetaAccountModel) async throws -> [NFT] {
        guard let chains = try? await fetchSupportedChains() else {
            return []
        }

        let nfts = try await withThrowingTaskGroup(of: NFT?.self) { [weak self] group in
            guard let strongSelf = self else {
                return [NFT]()
            }

            for chain in chains {
                if let tokens = try? await strongSelf.fetchERC721Tokens(for: chain, wallet: wallet) {
                    for token in tokens {
                        group.addTask {
                            if let url = try? await strongSelf.fetchMetadataUrl(token: token, chain: chain), url.isTLSScheme {
                                if let metadata = try? await strongSelf.fetchNftMetadata(url: url) {
                                    let nft = NFT(chain: chain, tokenId: token.tokenID, tokenName: token.tokenName, smartContract: token.contractAddress, metadata: metadata)
                                    return nft
                                }

                                return nil
                            }
                            return nil
                        }
                    }
                }
            }

            var result: [NFT] = []

            for try await nft in group {
                if let nft = nft {
                    result.append(nft)
                }
            }

            return result
        }

        return nfts
    }
}
