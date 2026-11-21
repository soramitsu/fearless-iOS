import RobinHood
import SSFModels
import XCTest
@testable import fearless

final class CovFNftFetchingTests: XCTestCase {
    func testSupportedChainsFilterAndRepositoryError() async throws {
        let fixture = CovFNftFixture()
        let unsupported = CovFFixtures.asset().chain
        fixture.chains.items = [fixture.chain, unsupported]
        let chains = try await fixture.service.fetchSupportedChains()
        XCTAssertEqual(chains, [fixture.chain])
        fixture.chains.failure = NSError(domain: "catalog", code: 1)
        do {
            _ = try await fixture.service.fetchSupportedChains()
            XCTFail("Catalog error must propagate")
        } catch { XCTAssertEqual((error as NSError).domain, "catalog") }
    }

    func testOwnedNftsAndCollectionsPreserveMetadataAndOwnerRequest() async throws {
        let fixture = CovFNftFixture()
        let wallet = AccountGenerator.generateMetaAccount()
        let nfts = try await fixture.service.fetchNfts(for: wallet, excludeFilters: [], chains: nil)
        XCTAssertEqual(nfts.map(\.title), ["Artwork"])
        XCTAssertEqual(nfts.first?.tokenId, "0x01")
        XCTAssertEqual(nfts.first?.chain, fixture.chain)
        let collections = try await fixture.service.fetchCollections(for: wallet, excludeFilters: [], chains: [])
        XCTAssertEqual(collections.map(\.name), ["Collection"])
        XCTAssertEqual(collections.first?.numberOfTokens, 2)
        let owners = fixture.queue.requests.compactMap { URLComponents(url: $0.url ?? fixture.fallbackURL, resolvingAgainstBaseURL: false) }
            .flatMap { $0.queryItems ?? [] }.filter { $0.name == "owner" }.compactMap(\.value)
        XCTAssertEqual(owners, Array(repeating: wallet.fetch(for: fixture.chain.accountRequest())?.toAddress(), count: 2).compactMap { $0 })
    }

    func testSelectedChainsExcludeUnsupportedCatalogEntries() async throws {
        let fixture = CovFNftFixture()
        let wallet = AccountGenerator.generateMetaAccount()
        let unsupported = CovFFixtures.asset().chain
        let nfts = try await fixture.service.fetchNfts(for: wallet, excludeFilters: [], chains: [unsupported])
        let collections = try await fixture.service.fetchCollections(for: wallet, excludeFilters: [], chains: [unsupported])
        XCTAssertTrue(nfts.isEmpty)
        XCTAssertTrue(collections.isEmpty)
        XCTAssertTrue(fixture.queue.requests.isEmpty)
        let selected = try await fixture.service.fetchNfts(for: wallet, excludeFilters: [], chains: [fixture.chain, unsupported])
        XCTAssertEqual(selected.count, 1)
        XCTAssertEqual(fixture.queue.requests.count, 1)
    }

    func testCollectionPaginationAndTokenOwnershipPreserveServerResponse() async throws {
        let fixture = CovFNftFixture()
        let batch = try await fixture.service.fetchCollectionNfts(collectionAddress: "0x1234", chain: fixture.chain, nextId: "page-one")
        XCTAssertEqual(batch.nfts?.map(\.title), ["Artwork"])
        XCTAssertEqual(batch.nextTokenId, "page-two")
        let owners = try await fixture.service.fetchOwners(for: "0x1234", tokenId: "0x01", chain: fixture.chain)
        XCTAssertEqual(owners, ["0xowner"])
        let queries = fixture.queue.requests.compactMap { $0.url }.compactMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        XCTAssertTrue(queries.flatMap { $0.queryItems ?? [] }.contains(URLQueryItem(name: "startToken", value: "page-one")))
        XCTAssertTrue(queries.flatMap { $0.queryItems ?? [] }.contains(URLQueryItem(name: "tokenId", value: "0x01")))
    }

    func testNetworkFailuresProduceEmptyResultsAndAFailedCollectionPageIsReported() async throws {
        let fixture = CovFNftFixture()
        fixture.queue.failure = NSError(domain: "offline", code: 7)
        let wallet = AccountGenerator.generateMetaAccount()
        let nfts = try await fixture.service.fetchNfts(for: wallet, excludeFilters: [], chains: nil)
        let collections = try await fixture.service.fetchCollections(for: wallet, excludeFilters: [], chains: nil)
        do {
            _ = try await fixture.service.fetchCollectionNfts(collectionAddress: "collection", chain: fixture.chain, nextId: nil)
            XCTFail("an empty page without a next token would read as the collection's last page")
        } catch {
            XCTAssertEqual((error as NSError).domain, "offline")
        }
        let owners = try await fixture.service.fetchOwners(for: "collection", tokenId: "1", chain: fixture.chain)
        XCTAssertTrue(nfts.isEmpty)
        XCTAssertTrue(collections.isEmpty)
        XCTAssertTrue(owners.isEmpty)
        XCTAssertEqual(fixture.queue.requests.count, 4)
    }

    func testAbsentResponseArraysAreHandledAsEmpty() async throws {
        let fixture = CovFNftFixture()
        fixture.queue.emptyPayloads = true
        let wallet = AccountGenerator.generateMetaAccount()
        let nfts = try await fixture.service.fetchNfts(for: wallet, excludeFilters: [], chains: nil)
        let collections = try await fixture.service.fetchCollections(for: wallet, excludeFilters: [], chains: nil)
        let owners = try await fixture.service.fetchOwners(for: "collection", tokenId: "1", chain: fixture.chain)
        XCTAssertTrue(nfts.isEmpty)
        XCTAssertTrue(collections.isEmpty)
        XCTAssertTrue(owners.isEmpty)
    }
}

private final class CovFNftFixture {
    let fallbackURL = URL(fileURLWithPath: "/")
    let chains = CovFRepository<ChainModel>()
    let queue = CovFNftQueue()
    let chain: ChainModel
    lazy var service = AlchemyNftFetchingService(
        operationFactory: AlchemyNFTOperationFactory(), chainRepository: AnyDataProviderRepository(chains), operationQueue: queue, logger: Logger.shared
    )

    init() {
        chain = ChainModel(
            rank: nil, disabled: false, chainId: "1", parentId: nil, paraId: nil, name: "Ethereum", assets: [],
            xcm: nil, nodes: [], addressPrefix: 0, icon: nil, options: [.ethereum, .nft], iosMinAppVersion: nil, identityChain: nil
        )
        chains.items = [chain]
        queue.maxConcurrentOperationCount = 1
    }
}

private final class CovFNftQueue: OperationQueue, @unchecked Sendable {
    var failure: Error?
    var emptyPayloads = false
    var requests: [URLRequest] = []

    override func addOperations(_ operations: [Operation], waitUntilFinished wait: Bool) {
        for operation in operations {
            if let operation = operation as? NetworkOperation<AlchemyOwnedNftsResponse> {
                prepare(operation, json: #"{"ownedNfts":[{"title":"Artwork","id":{"tokenId":"0x01"}}]}"#)
            } else if let operation = operation as? NetworkOperation<AlchemyNftCollectionsResponse> {
                prepare(operation, json: #"{"totalCount":1,"contracts":[{"name":"Collection","numDistinctTokensOwned":2}]}"#)
            } else if let operation = operation as? NetworkOperation<AlchemyNftsResponse> {
                prepare(operation, json: #"{"nfts":[{"title":"Artwork"}],"nextToken":"page-two"}"#)
            } else if let operation = operation as? NetworkOperation<AlchemyOwnersResponse?> {
                prepare(operation, json: #"{"owners":["0xowner"]}"#)
            }
        }
        super.addOperations(operations, waitUntilFinished: wait)
    }

    private func prepare<T>(_ operation: NetworkOperation<T>, json: String) {
        do {
            requests.append(try operation.requestFactory.createRequest())
            if let failure {
                operation.result = .failure(failure)
            } else {
                let payload = emptyPayloads ? #"{"totalCount":0}"# : json
                operation.result = operation.resultFactory.createResult(data: Data(payload.utf8), response: nil, error: nil)
            }
        } catch { operation.result = .failure(error) }
    }
}
