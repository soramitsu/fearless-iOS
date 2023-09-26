// import Foundation
// import RobinHood
// import SSFNetwork
// import SSFModels
// import Web3
// import Web3ContractABI
//
// final class EtherscanNftFetchingService: BaseNftFetchingService {
//    private let chainRegistry: ChainRegistryProtocol
//    private let nftOperationFactory: NFTOperationFactoryProtocol
//    private let networkOperationFactory: NetworkOperationFactoryProtocol
//    private let logger: LoggerProtocol
//
//    init(
//        chainRegistry: ChainRegistryProtocol,
//        nftOperationFactory: NFTOperationFactoryProtocol,
//        chainRepository: AnyDataProviderRepository<ChainModel>,
//        operationQueue: OperationQueue,
//        networkOperationFactory: NetworkOperationFactoryProtocol,
//        logger: LoggerProtocol
//    ) {
//        self.chainRegistry = chainRegistry
//        self.nftOperationFactory = nftOperationFactory
//        self.networkOperationFactory = networkOperationFactory
//        self.logger = logger
//
//        super.init(chainRepository: chainRepository, operationQueue: operationQueue)
//    }
//
//    private func fetchCollections(for chain: ChainModel, wallet: MetaAccountModel) async throws -> [NFTCollection]? {
//        guard let address = wallet.fetch(for: chain.accountRequest())?.toAddress() else {
//            throw SS58AddressFactoryError.unexpectedAddress
//        }
//
//        return try await withCheckedThrowingContinuation { continuation in
//            let fetchNftsOperation = nftOperationFactory.fetchCollections(chain: chain, address: address)
//
//            fetchNftsOperation.targetOperation.completionBlock = {
//                do {
//                    let collections = try fetchNftsOperation.targetOperation.extractNoCancellableResultData()
//                    continuation.resume(with: .success(collections))
//                } catch {
//                    continuation.resume(with: .failure(error))
//                }
//            }
//
//            operationQueue.addOperations(fetchNftsOperation.allOperations, waitUntilFinished: true)
//        }
//    }
//
//    private func fetchERC721Tokens(for _: ChainModel, wallet _: MetaAccountModel) async throws -> [EtherscanNftResponseElement] {
//        []
////        guard let address = wallet.fetch(for: chain.accountRequest())?.toAddress() else {
////            throw SS58AddressFactoryError.unexpectedAddress
////        }
////
////        return try await withCheckedThrowingContinuation { continuation in
////            let fetchNftsOperation = nftOperationFactory.fetchNFTs(for: "", chain: chain, address: address)
////
////            fetchNftsOperation.targetOperation.completionBlock = {
////                do {
////                    let nfts = try fetchNftsOperation.targetOperation.extractNoCancellableResultData()
////                    continuation.resume(with: .success(nfts))
////                } catch {
////                    continuation.resume(with: .failure(error))
////                }
////            }
////
////            operationQueue.addOperations(fetchNftsOperation.allOperations, waitUntilFinished: true)
////        }
//    }
//
//    private func fetchMetadataUrl(token: EtherscanNftResponseElement, chain: ChainModel) async throws -> String? {
//        guard let ws = chainRegistry.getEthereumConnection(for: chain.chainId) else {
//            throw ChainRegistryError.connectionUnavailable
//        }
//
//        let contractAddress = try EthereumAddress(hex: token.contractAddress, eip55: false)
//        let contract = ws.Contract(type: GenericERC721Contract.self, address: contractAddress)
//
//        guard let tokenId = BigUInt(string: token.tokenID) else {
//            throw ConvenienceError(error: "fetchMetadataUrl: incorrect token id: \(token.tokenID)")
//        }
//
//        return try await withCheckedThrowingContinuation { continuation in
//            contract.tokenURI(tokenId: tokenId).call { [weak self] response, error in
//                if let uri = response?["_tokenURI"] as? String {
//                    return continuation.resume(with: .success(uri))
//                } else if let error = error {
//                    return continuation.resume(with: .failure(error))
//                } else {
//                    self?.logger.error("Failed to fetch metadata url for token: \(token.tokenName)")
//                    return continuation.resume(with: .failure(NFTFetchingServiceError.emptyResponse))
//                }
//            }
//        }
//    }
//
//    private func fetchNftMetadata(url: URL) async throws -> NFTMetadata {
//        try await withCheckedThrowingContinuation { continuation in
//            let fetchMetadataOperation: BaseOperation<NFTMetadata> = networkOperationFactory.fetchData(from: url)
//
//            fetchMetadataOperation.completionBlock = { [weak self] in
//                do {
//                    let metadata = try fetchMetadataOperation.extractNoCancellableResultData()
//                    return continuation.resume(with: .success(metadata))
//                } catch {
//                    self?.logger.error("Failed to fetch NFT metadata from url: \(url)")
//                    return continuation.resume(with: .failure(error))
//                }
//            }
//
//            operationQueue.addOperation(fetchMetadataOperation)
//        }
//    }
// }
//
// extension EtherscanNftFetchingService: NFTFetchingServiceProtocol {
//    func fetchNfts(for _: MetaAccountModel, collectionId _: String?) async throws -> [NFT] {
//        []
//    }
//
//    func fetchNftsHistory(for wallet: MetaAccountModel) async throws -> [NFTHistoryObject] {
//        guard let chains = try? await fetchSupportedChains() else {
//            return []
//        }
//
//        let history = try await withThrowingTaskGroup(of: [NFTHistoryObject]?.self) { [weak self] group in
//            guard let strongSelf = self else {
//                return [NFTHistoryObject]()
//            }
//
//            for chain in chains {
//                group.addTask {
//                    if let tokens = try? await strongSelf.fetchERC721Tokens(for: chain, wallet: wallet) {
//                        let mappedObjects = tokens.compactMap { NFTHistoryObject(chain: chain, metadata: $0) }
//                        return mappedObjects
//                    } else {
//                        return []
//                    }
//                }
//            }
//
//            var result: [NFTHistoryObject] = []
//
//            for try await tokens in group {
//                if let tokens = tokens {
//                    result.append(contentsOf: tokens)
//                }
//            }
//
//            return result
//        }
//
//        return history
//    }
//
//    func fetchNfts(for history: [NFTHistoryObject]) async throws -> [NFT] {
//        let nfts = try await withThrowingTaskGroup(of: NFT?.self) { [weak self] group in
//            guard let strongSelf = self else {
//                return [NFT]()
//            }
//
//            for historyObject in history {
//                group.addTask {
//                    if let uri = try? await strongSelf.fetchMetadataUrl(token: historyObject.metadata, chain: historyObject.chain), let url = URL(string: uri), let normalizedURL = url.normalizedIpfsURL {
//                        if let metadata = try? await strongSelf.fetchNftMetadata(url: normalizedURL) {
//                            let nft = NFT(chain: historyObject.chain, tokenId: historyObject.metadata.tokenID, tokenName: historyObject.metadata.tokenName, smartContract: historyObject.metadata.contractAddress, metadata: metadata)
//                            return nft
//                        }
//
//                        let nft = NFT(chain: historyObject.chain, tokenId: historyObject.metadata.tokenID, tokenName: historyObject.metadata.tokenName, smartContract: historyObject.metadata.contractAddress, metadata: nil)
//                        return nft
//                    } else {
//                        let nft = NFT(chain: historyObject.chain, tokenId: historyObject.metadata.tokenID, tokenName: historyObject.metadata.tokenName, smartContract: historyObject.metadata.contractAddress, metadata: nil)
//                        return nft
//                    }
//                }
//            }
//
//            var result: [NFT] = []
//
//            for try await nft in group {
//                if let nft = nft {
//                    result.append(nft)
//                }
//            }
//
//            return result
//        }
//
//        return nfts
//    }
//
//    func fetchNfts(for wallet: MetaAccountModel) async throws -> [NFT] {
//        guard let chains = try? await fetchSupportedChains() else {
//            return []
//        }
//
//        let nfts = try await withThrowingTaskGroup(of: NFT?.self) { [weak self] group in
//            guard let strongSelf = self else {
//                return [NFT]()
//            }
//
//            for chain in chains {
//                if let tokens = try? await strongSelf.fetchERC721Tokens(for: chain, wallet: wallet) {
//                    for token in tokens {
//                        group.addTask {
//                            if let uri = try? await strongSelf.fetchMetadataUrl(token: token, chain: chain), let url = URL(string: uri), url.isTLSScheme {
//                                if let metadata = try? await strongSelf.fetchNftMetadata(url: url) {
//                                    let nft = NFT(chain: chain, tokenId: token.tokenID, tokenName: token.tokenName, smartContract: token.contractAddress, metadata: metadata)
//                                    return nft
//                                }
//
//                                return nil
//                            }
//                            return nil
//                        }
//                    }
//                }
//            }
//
//            var result: [NFT] = []
//
//            for try await nft in group {
//                if let nft = nft {
//                    result.append(nft)
//                }
//            }
//
//            return result
//        }
//
//        return nfts
//    }
//
//    func fetchCollections(for wallet: MetaAccountModel) async throws -> [NFTCollection] {
//        guard let chains = try? await fetchSupportedChains() else {
//            return []
//        }
//
//        let collections = try await withThrowingTaskGroup(of: [NFTCollection]?.self) { [weak self] group in
//            guard let strongSelf = self else {
//                return [NFTCollection]()
//            }
//
//            for chain in chains {
//                group.addTask {
//                    let collections = try? await strongSelf.fetchCollections(for: chain, wallet: wallet)
//                    return collections
//                }
//            }
//
//            var result: [NFTCollection] = []
//
//            for try await collection in group {
//                if let collection = collection {
//                    result.append(contentsOf: collection)
//                }
//            }
//
//            return result
//        }
//
//        return collections
//    }
// }
