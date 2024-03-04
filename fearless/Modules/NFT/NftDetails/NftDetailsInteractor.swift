import UIKit

final class NftDetailsInteractor {
    // MARK: - Private properties

    private let nftFetchingService: NFTFetchingServiceProtocol
    private let logger: LoggerProtocol
    private weak var output: NftDetailsInteractorOutput?
    private var nft: NFT?

    init(
        nft: NFT?,
        nftFetchingService: NFTFetchingServiceProtocol,
        logger: LoggerProtocol
    ) {
        self.nft = nft
        self.nftFetchingService = nftFetchingService
        self.logger = logger
    }
}

// MARK: - NftDetailsInteractorInput

extension NftDetailsInteractor: NftDetailsInteractorInput {
    func setup(with output: NftDetailsInteractorOutput) {
        self.output = output

        if let nft = nft {
            output.didReceive(nft: nft)
        }
        fetchData()
    }

    func fetchData() {
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
                    await MainActor.run(body: {
                        output?.didReceive(owners: owners)
                    })
                }
            } catch {
                logger.customError(error)
            }
        }
    }
}
