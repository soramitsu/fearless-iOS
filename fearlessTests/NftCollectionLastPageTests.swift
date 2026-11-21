import RobinHood
import SSFModels
import XCTest
@testable import fearless

/// The collection screen asks for the next page with the token the last page named. After the last page there is no
/// token, and asking without one fetches the first page again, so every scroll past the end appended the first page's
/// NFTs once more. Alchemy also answered a failed page with an empty page without a token, which read as the end.
final class NftCollectionLastPageTests: XCTestCase {
    func testScrollingPastTheLastPageAsksForNoFurtherPage() {
        let chain = CovHNftFixtures.chain()
        let first = CovHNftFixtures.nft(chain: chain, tokenId: "0x01")
        let second = CovHNftFixtures.nft(chain: chain, tokenId: "0x02")
        let service = CovHNftFetchingStub()
        let interactor = NftCollectionInteractor(
            collection: CovHNftFixtures.collection(chain: chain, address: "0xlast", nfts: []),
            nftFetchingService: service
        )
        let output = CovHNftCollectionOutputSpy()
        interactor.setup(with: output)

        service.batch = .success(NFTBatch(nfts: [first], nextTokenId: "page-two"))
        interactor.initialSetup()
        CovHNftWait.until { output.collections.count == 2 }

        service.batch = .success(NFTBatch(nfts: [second], nextTokenId: nil))
        interactor.fetchData()
        CovHNftWait.until { output.collections.count == 3 }

        // What the API answers for a request without a token: the first page.
        service.batch = .success(NFTBatch(nfts: [first], nextTokenId: "page-two"))
        interactor.fetchData()
        CovHNftWait.until(1) { output.collections.count == 4 }
        interactor.fetchData()
        CovHNftWait.spin(0.3)

        XCTAssertEqual(service.batchRequests.map(\.1), [nil, "page-two"], "nothing is asked for after the last page")
        XCTAssertEqual(output.collections.count, 3)
        XCTAssertEqual(output.collections.last?.availableNfts, [first, second], "no NFT is shown twice")
    }

    func testAnEmptyNextTokenEndsTheCollection() {
        let chain = CovHNftFixtures.chain()
        let only = CovHNftFixtures.nft(chain: chain, tokenId: "0x01")
        let service = CovHNftFetchingStub()
        let interactor = NftCollectionInteractor(
            collection: CovHNftFixtures.collection(chain: chain, address: "0xempty-token", nfts: []),
            nftFetchingService: service
        )
        let output = CovHNftCollectionOutputSpy()
        interactor.setup(with: output)

        service.batch = .success(NFTBatch(nfts: [only], nextTokenId: ""))
        interactor.initialSetup()
        CovHNftWait.until { output.collections.count == 2 }

        interactor.fetchData()
        CovHNftWait.spin(0.3)

        XCTAssertEqual(service.batchRequests.map(\.1), [nil])
        XCTAssertEqual(output.collections.last?.availableNfts, [only])
    }

    func testAlchemyReportsAFailedCollectionPageInsteadOfAnEmptyLastPage() async {
        let queue = NftCollectionPageQueue(pages: [.failure(NftCollectionPageError.offline)])
        let service = NftCollectionPageQueue.service(queue: queue)

        do {
            let batch = try await service.fetchCollectionNfts(
                collectionAddress: "0xfailed",
                chain: NftCollectionPageQueue.ethereumChain,
                nextId: "page-two"
            )
            XCTFail("a failed page read as \(batch.nfts?.count ?? 0) NFTs and next token \(batch.nextTokenId ?? "nil")")
        } catch {
            XCTAssertEqual(error as? NftCollectionPageError, .offline)
        }
        XCTAssertEqual(queue.startTokens, ["page-two"])
    }

    func testAFailedPageInTheMiddleIsAskedForAgainNotTakenForTheEnd() {
        let queue = NftCollectionPageQueue(pages: [
            .success(#"{"nfts":[{"title":"One","id":{"tokenId":"0x01"}}],"nextToken":"page-two"}"#),
            .failure(NftCollectionPageError.offline),
            .success(#"{"nfts":[{"title":"Two","id":{"tokenId":"0x02"}}]}"#)
        ])
        let interactor = NftCollectionInteractor(
            collection: CovHNftFixtures.collection(chain: NftCollectionPageQueue.ethereumChain, address: "0xmiddle", nfts: []),
            nftFetchingService: NftCollectionPageQueue.service(queue: queue)
        )
        let output = CovHNftCollectionOutputSpy()
        interactor.setup(with: output)

        interactor.initialSetup()
        CovHNftWait.until { output.collections.count == 2 }

        interactor.fetchData()
        CovHNftWait.until { queue.startTokens.count == 2 }
        CovHNftWait.spin(0.3)

        interactor.fetchData()
        CovHNftWait.until { queue.startTokens.count == 3 && output.collections.count >= 3 }
        CovHNftWait.spin(0.2)

        XCTAssertEqual(queue.startTokens, [nil, "page-two", "page-two"], "the failed page is asked for again")
        XCTAssertEqual(output.collections.last?.availableNfts?.map(\.tokenId), ["0x01", "0x02"])
    }
}

private enum NftCollectionPageError: Error, Equatable {
    case offline
}

/// Answers each Alchemy `getNFTsForCollection` request with the next prepared page and records its `startToken`.
private final class NftCollectionPageQueue: OperationQueue, @unchecked Sendable {
    static let ethereumChain = ChainModel(
        rank: nil, disabled: false, chainId: "1", parentId: nil, paraId: nil, name: "Ethereum", assets: [],
        xcm: nil, nodes: [], addressPrefix: 0, icon: nil, options: [.ethereum, .nft], iosMinAppVersion: nil, identityChain: nil
    )

    static func service(queue: NftCollectionPageQueue) -> AlchemyNftFetchingService {
        AlchemyNftFetchingService(
            operationFactory: AlchemyNFTOperationFactory(),
            chainRepository: AnyDataProviderRepository(CovFRepository<ChainModel>()),
            operationQueue: queue,
            logger: Logger.shared
        )
    }

    private let lock = NSLock()
    private var pages: [Result<String, Error>]
    private var storedStartTokens: [String?] = []

    var startTokens: [String?] { lock.lock(); defer { lock.unlock() }; return storedStartTokens }

    init(pages: [Result<String, Error>]) {
        self.pages = pages
        super.init()
        maxConcurrentOperationCount = 1
    }

    override func addOperations(_ operations: [Operation], waitUntilFinished wait: Bool) {
        for case let operation as NetworkOperation<AlchemyNftsResponse> in operations {
            let request = try? operation.requestFactory.createRequest()
            let startToken = request?.url
                .flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?
                .queryItems?
                .first { $0.name == "startToken" }?
                .value
            lock.lock()
            storedStartTokens.append(startToken)
            let page = pages.isEmpty ? .failure(NftCollectionPageError.offline) : pages.removeFirst()
            lock.unlock()
            switch page {
            case let .success(json):
                operation.result = operation.resultFactory.createResult(data: Data(json.utf8), response: nil, error: nil)
            case let .failure(error):
                operation.result = .failure(error)
            }
        }
        super.addOperations(operations, waitUntilFinished: wait)
    }
}
