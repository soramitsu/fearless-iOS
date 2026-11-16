import Foundation
import RobinHood
import XCTest
@testable import fearless

final class CovGAlchemyNFTTests: XCTestCase {
    private let factory = AlchemyNFTOperationFactory()
    private let media = #"[{"thumbnail":"https://media.invalid/thumb","raw":"ipfs://image","format":"png"}]"#
    private var collection: String {
        """
        {"address":"contract","numDistinctTokensOwned":2,"isSpam":false,"title":"Collection title",
         "name":"Collection","contractDeployer":"creator","totalSupply":"99","tokenType":"ERC721",
         "openSea":{"floorPrice":1.5,"description":"Collection description"},"media":\(media)}
        """
    }

    private func nft(poster: Bool) -> String {
        """
        {"title":"NFT title","description":"NFT description","id":{"tokenId":"0x01","tokenMetadata":{"tokenType":"ERC721"}},
         "contract":{"address":"contract"},"metadata":{"name":"Metadata name","description":"Metadata description"
         \(poster ? ",\"poster\":\"https://media.invalid/poster\"" : "")},"media":\(media),"contractMetadata":\(collection)}
        """
    }

    func testCollectionsRequestAndMappingPreserveContractMetadata() throws {
        let chain = try CovGOperationFixtures.chain()
        let wrapper = factory.fetchCollections(
            chain: chain, address: "owner +/", excludeFilters: [.init(type: .spam), .init(type: .airdrop)]
        )
        let network = try CovGOperationFixtures.network(wrapper, as: AlchemyNftCollectionsResponse.self)
        let request = try network.requestFactory.createRequest()
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.host, "eth-mainnet.g.alchemy.com")
        XCTAssertTrue(request.url?.path.hasSuffix("/getContractsForOwner") == true)
        let items = try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(items.first { $0.name == "owner" }?.value, "owner +/")
        XCTAssertEqual(items.filter { $0.name == "excludeFilters[]" }.compactMap(\.value), ["SPAM", "AIRDROPS"])
        XCTAssertEqual(items.first { $0.name == "withMetadata" }?.value, "true")
        CovGOperationFixtures.checkNetworkFailures(network)
        try CovGOperationFixtures.respond(network, json: "{\"totalCount\":1,\"contracts\":[\(collection)]}")
        let value = try XCTUnwrap(CovGOperationFixtures.run(wrapper)?.first)
        assertCollection(value)
        XCTAssertEqual(value.chain.chainId, chain.chainId)
    }

    func testOwnedNFTsMapPosterAndFallbackThumbnail() throws {
        let wrapper = factory.fetchNFTs(
            chain: try CovGOperationFixtures.chain(), address: "owner", excludeFilters: [.init(type: .airdrop)]
        )
        let network = try CovGOperationFixtures.network(wrapper, as: AlchemyOwnedNftsResponse.self)
        let request = try network.requestFactory.createRequest()
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(request.url?.path.hasSuffix("/getNFTs") == true)
        XCTAssertTrue(request.url?.query?.contains("AIRDROPS") == true)
        CovGOperationFixtures.checkNetworkFailures(network)
        try CovGOperationFixtures.respond(network, json: "{\"ownedNfts\":[\(nft(poster: true)),\(nft(poster: false)),{}]}")
        let values = try XCTUnwrap(CovGOperationFixtures.run(wrapper))
        XCTAssertEqual(values.count, 3)
        assertNFT(values[0], poster: true)
        assertNFT(values[1], poster: false)
        XCTAssertNil(values[2].tokenId)
        XCTAssertNil(values[2].media)
        XCTAssertNil(values[2].mediaThumbnail)
    }

    func testCollectionNFTsCarryPaginationAndMetadata() throws {
        for nextId in [nil, "token +/"] as [String?] {
            let wrapper = factory.fetchCollectionNfts(chain: try CovGOperationFixtures.chain(id: "137"), address: "contract", nextId: nextId)
            let network = try CovGOperationFixtures.network(wrapper, as: AlchemyNftsResponse.self)
            let request = try network.requestFactory.createRequest()
            XCTAssertEqual(request.url?.host, "polygon-mainnet.g.alchemy.com")
            XCTAssertTrue(request.url?.path.hasSuffix("/getNFTsForCollection") == true)
            let items = try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems)
            XCTAssertEqual(items.first { $0.name == "startToken" }?.value, nextId)
            XCTAssertEqual(items.first { $0.name == "limit" }?.value, "100")
            XCTAssertEqual(items.first { $0.name == "contractAddress" }?.value, "contract")
            CovGOperationFixtures.checkNetworkFailures(network)
            try CovGOperationFixtures.respond(network, json: "{\"nfts\":[\(nft(poster: true)),\(nft(poster: false))],\"nextToken\":\"next\"}")
            let batch = try XCTUnwrap(CovGOperationFixtures.run(wrapper))
            XCTAssertEqual(batch.nextTokenId, "next")
            let nfts = try XCTUnwrap(batch.nfts)
            XCTAssertEqual(nfts.count, 2)
            assertNFT(nfts[0], poster: true)
            assertNFT(nfts[1], poster: false)
        }
    }

    func testOwnersRequestAndMapping() throws {
        let wrapper = factory.fetchOwners(for: try CovGOperationFixtures.chain(), address: "contract", tokenId: "0x01")
        let network = try CovGOperationFixtures.network(wrapper, as: AlchemyOwnersResponse?.self)
        let request = try network.requestFactory.createRequest()
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(request.url?.path.hasSuffix("/getOwnersForToken") == true)
        let items = try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(items.first { $0.name == "contractAddress" }?.value, "contract")
        XCTAssertEqual(items.first { $0.name == "tokenId" }?.value, "0x01")
        CovGOperationFixtures.checkNetworkFailures(network)
        try CovGOperationFixtures.respond(network, json: #"{"owners":["alice","bob"]}"#)
        XCTAssertEqual(try CovGOperationFixtures.run(wrapper), ["alice", "bob"])
    }

    func testMissingOptionalCollectionsAndNFTsRemainNil() throws {
        let chain = try CovGOperationFixtures.chain()
        let collections = factory.fetchCollections(chain: chain, address: "owner", excludeFilters: [])
        try CovGOperationFixtures.respond(CovGOperationFixtures.network(collections, as: AlchemyNftCollectionsResponse.self), json: #"{"totalCount":0}"#)
        XCTAssertNil(try CovGOperationFixtures.run(collections))
        let owned = factory.fetchNFTs(chain: chain, address: "owner", excludeFilters: [])
        try CovGOperationFixtures.respond(CovGOperationFixtures.network(owned, as: AlchemyOwnedNftsResponse.self), json: "{}")
        XCTAssertNil(try CovGOperationFixtures.run(owned))
        let batch = factory.fetchCollectionNfts(chain: chain, address: "contract", nextId: nil)
        try CovGOperationFixtures.respond(CovGOperationFixtures.network(batch, as: AlchemyNftsResponse.self), json: "{}")
        XCTAssertEqual(try CovGOperationFixtures.run(batch), NFTBatch(nfts: nil, nextTokenId: nil))
        let owners = factory.fetchOwners(for: chain, address: "contract", tokenId: "0")
        let network = try CovGOperationFixtures.network(owners, as: AlchemyOwnersResponse?.self)
        network.result = .success(nil)
        XCTAssertNil(try CovGOperationFixtures.run(owners))
    }

    func testUnsupportedChainsReturnNamedErrorsForEveryEndpoint() throws {
        for id in ["unknown", "56"] {
            let chain = try CovGOperationFixtures.chain(id: id)
            assertUnsupported(factory.fetchNFTs(chain: chain, address: "a", excludeFilters: []))
            assertUnsupported(factory.fetchCollections(chain: chain, address: "a", excludeFilters: []))
            assertUnsupported(factory.fetchCollectionNfts(chain: chain, address: "a", nextId: nil))
            assertUnsupported(factory.fetchOwners(for: chain, address: "a", tokenId: "0"))
        }
    }

    func testRemoteErrorPropagatesThroughMapping() throws {
        let wrapper = factory.fetchNFTs(chain: try CovGOperationFixtures.chain(), address: "owner", excludeFilters: [])
        let network = try CovGOperationFixtures.network(wrapper, as: AlchemyOwnedNftsResponse.self)
        network.result = .failure(NSError(domain: "CovG.mapping", code: 91))
        XCTAssertThrowsError(try CovGOperationFixtures.run(wrapper)) { XCTAssertEqual(($0 as NSError).code, 91) }
    }

    private func assertUnsupported<T>(_ wrapper: CompoundOperationWrapper<T>) {
        XCTAssertThrowsError(try CovGOperationFixtures.run(wrapper)) {
            guard case let AlchemyNFTOperationFactoryError.chainUnsupported(name) = $0 else {
                return XCTFail("Expected unsupported chain, got \($0)")
            }
            XCTAssertEqual(name, "Coverage chain")
        }
    }

    private func assertCollection(_ collection: NFTCollection) {
        XCTAssertEqual(collection.address, "contract")
        XCTAssertEqual(collection.numberOfTokens, 2)
        XCTAssertEqual(collection.isSpam, false)
        XCTAssertEqual(collection.title, "Collection title")
        XCTAssertEqual(collection.name, "Collection")
        XCTAssertEqual(collection.creator, "creator")
        XCTAssertEqual(collection.price, 1.5)
        XCTAssertEqual(collection.tokenType, .erc721)
        XCTAssertEqual(collection.desc, "Collection description")
        XCTAssertEqual(collection.totalSupply, "99")
        XCTAssertEqual(collection.media?.first?.mediaPath, "ipfs://image")
        XCTAssertEqual(collection.media?.first?.format, "png")
    }

    private func assertNFT(_ nft: NFT, poster: Bool) {
        XCTAssertEqual(nft.tokenId, "0x01")
        XCTAssertEqual(nft.title, "NFT title")
        XCTAssertEqual(nft.description, "NFT description")
        XCTAssertEqual(nft.smartContract, "contract")
        XCTAssertEqual(nft.metadata?.name, "Metadata name")
        XCTAssertEqual(nft.metadata?.description, "Metadata description")
        XCTAssertEqual(nft.mediaThumbnail, poster ? "https://media.invalid/poster" : "https://media.invalid/thumb")
        XCTAssertEqual(nft.tokenType, .erc721)
        XCTAssertEqual(nft.collectionName, "Collection")
        XCTAssertEqual(nft.media?.first?.thumbnail, "https://media.invalid/thumb")
        if let collection = nft.collection { assertCollection(collection) } else { XCTFail("Missing collection") }
    }
}
