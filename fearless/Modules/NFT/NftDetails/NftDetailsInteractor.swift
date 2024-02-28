import UIKit

final class NftDetailsInteractor {
    // MARK: - Private properties

    private let nftFetchingService: NFTFetchingServiceProtocol
    private weak var output: NftDetailsInteractorOutput?
    private var nft: NFT?
    private var isReady: Bool = false

    init(nft: NFT?, nftFetchingService: NFTFetchingServiceProtocol) {
        self.nft = nft
        self.nftFetchingService = nftFetchingService
    }
}

// MARK: - NftDetailsInteractorInput

extension NftDetailsInteractor: NftDetailsInteractorInput {
    func initialSetup() {
        let wasReady = isReady
        isReady = true

        if !wasReady {
            fetchData()
        }
    }

    func setup(with output: NftDetailsInteractorOutput) {
        self.output = output

        if let nft = nft {
            output.didReceive(nft: nft)
        }
    }

    func fetchData() {
        guard isReady else {
            return
        }

        isReady = false

        Task {
            do {
                if let address = nft?.smartContract,
                   let tokenId = nft?.tokenId,
                   let chain = nft?.collection?.chain {
                    let owners = try await nftFetchingService.fetchOwners(
                        for: address, tokenId:
                        tokenId,
                        chain: chain
                    )

                    self.isReady = true
                    await MainActor.run(body: {
                        output?.didReceive(owners: owners)
                    })
                }
            }
        }
    }
}
