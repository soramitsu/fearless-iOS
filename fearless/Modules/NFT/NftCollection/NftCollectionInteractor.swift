import UIKit

final class NftCollectionInteractor {
    // MARK: - Private properties

    private weak var output: NftCollectionInteractorOutput?
    private var collection: NFTCollection
    private var isReady: Bool = false
    private var page: Int = 0

    private let nftFetchingService: NFTFetchingServiceProtocol

    init(
        collection: NFTCollection,
        nftFetchingService: NFTFetchingServiceProtocol
    ) {
        self.collection = collection
        self.nftFetchingService = nftFetchingService
    }
}

// MARK: - NftCollectionInteractorInput

extension NftCollectionInteractor: NftCollectionInteractorInput {
    func initialSetup() {
        let wasReady = isReady
        isReady = true

        if !wasReady {
            fetchData()
        }
    }

    func setup(with output: NftCollectionInteractorOutput) {
        self.output = output

        output.didReceive(collection: collection)
    }

    func fetchData(page: Int = 0) {
        guard isReady else {
            return
        }

        isReady = false

        Task {
            do {
                if let address = collection.address {
                    let nfts = try await nftFetchingService.fetchCollectionNfts(
                        collectionAddress: address,
                        chain: collection.chain,
                        offset: page * 100
                    )
                    let availableNfts = nfts.filter { collection.nfts?.contains($0) != true }
                    if let _ = collection.availableNfts {
                        collection.availableNfts?.append(contentsOf: availableNfts)
                    } else {
                        collection.availableNfts = availableNfts
                    }

                    self.page += 1
                    self.isReady = true
                    await MainActor.run(body: {
                        output?.didReceive(collection: collection)
                    })
                }
            }
        }
    }

    func loadNext() {
        fetchData(page: page)
    }
}
