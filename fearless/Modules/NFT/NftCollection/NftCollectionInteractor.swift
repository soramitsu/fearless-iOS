import UIKit

final class NftCollectionInteractor {
    // MARK: - Private properties

    private weak var output: NftCollectionInteractorOutput?
    private var collection: NFTCollection
    private var isReady: Bool = false
    private var nextTokenId: String?

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

    func fetchData() {
        guard isReady else {
            return
        }

        isReady = false

        Task {
            do {
                if let address = collection.address {
                    let nftBatch = try await nftFetchingService.fetchCollectionNfts(
                        collectionAddress: address,
                        chain: collection.chain,
                        nextId: nextTokenId
                    )
                    nextTokenId = nftBatch.nextTokenId
                    let ids = nftBatch.nfts?.compactMap { $0.tokenId }
                    let availableNfts = nftBatch.nfts?.filter { collection.nfts?.contains($0) != true } ?? []
                    if let _ = collection.availableNfts {
                        collection.availableNfts?.append(contentsOf: availableNfts)
                    } else {
                        collection.availableNfts = availableNfts
                    }

                    self.isReady = true
                    await MainActor.run(body: {
                        output?.didReceive(collection: collection)
                    })
                }
            }
        }
    }
}
