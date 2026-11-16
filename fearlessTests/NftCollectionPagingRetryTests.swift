import XCTest
@testable import fearless

/// A failed page used to leave the collection screen unable to load any further page.
final class NftCollectionPagingRetryTests: XCTestCase {
    func testAFailedPageIsAskedForAgainOnTheNextScroll() {
        let chain = CovHNftFixtures.chain()
        let next = CovHNftFixtures.nft(chain: chain, tokenId: "0x02")
        let service = CovHNftFetchingStub()
        service.batch = .failure(NSError(domain: "nft", code: 1))
        let interactor = NftCollectionInteractor(
            collection: CovHNftFixtures.collection(chain: chain, address: "0xretry", nfts: []),
            nftFetchingService: service
        )
        let output = CovHNftCollectionOutputSpy()
        interactor.setup(with: output)

        interactor.initialSetup()
        CovHNftWait.until { service.batchRequests.count == 1 }
        CovHNftWait.spin(0.2)
        XCTAssertEqual(output.collections.count, 1, "nothing new arrives with a failed page")

        service.batch = .success(NFTBatch(nfts: [next], nextTokenId: nil))
        interactor.fetchData()
        CovHNftWait.until { output.collections.count == 2 }

        XCTAssertEqual(service.batchRequests.map(\.1), [nil, nil], "the failed page is asked for again")
        XCTAssertEqual(output.collections.last?.availableNfts, [next])
    }

    func testPagesAreDeliveredOnTheMainThread() {
        let chain = CovHNftFixtures.chain()
        let service = CovHNftFetchingStub()
        service.batch = .success(NFTBatch(nfts: [CovHNftFixtures.nft(chain: chain, tokenId: "0x03")], nextTokenId: "next"))
        let interactor = NftCollectionInteractor(
            collection: CovHNftFixtures.collection(chain: chain, address: "0xmain", nfts: []),
            nftFetchingService: service
        )
        let output = NftCollectionThreadSpy()
        interactor.setup(with: output)

        interactor.initialSetup()
        CovHNftWait.until { output.deliveries.count == 2 }

        XCTAssertEqual(output.deliveries, [true, true])
    }
}

private final class NftCollectionThreadSpy: NftCollectionInteractorOutput {
    private let lock = NSLock()
    private var stored: [Bool] = []

    var deliveries: [Bool] { lock.lock(); defer { lock.unlock() }; return stored }

    func didReceive(collection _: NFTCollection) {
        lock.lock()
        stored.append(Thread.isMainThread)
        lock.unlock()
    }
}
