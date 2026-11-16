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

        guard let address = collection.address else {
            return
        }

        isReady = false

        let chain = collection.chain
        let nextId = nextTokenId
        Task { @MainActor [weak self, nftFetchingService] in
            do {
                let nftBatch = try await nftFetchingService.fetchCollectionNfts(
                    collectionAddress: address,
                    chain: chain,
                    nextId: nextId
                )
                self?.didReceive(nftBatch: nftBatch)
            } catch {
                // The next scroll asks for this page again.
                self?.isReady = true
            }
        }
    }

    private func didReceive(nftBatch: NFTBatch) {
        nextTokenId = nftBatch.nextTokenId

        let availableNfts = nftBatch.nfts?.filter { collection.nfts?.contains($0) != true } ?? []
        if collection.availableNfts != nil {
            collection.availableNfts?.append(contentsOf: availableNfts)
        } else {
            collection.availableNfts = availableNfts
        }

        isReady = true
        output?.didReceive(collection: collection)
    }
}
