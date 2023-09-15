import UIKit

final class NftDetailsInteractor {
    // MARK: - Private properties

    private weak var output: NftDetailsInteractorOutput?
    private var nft: NFT?

    init(nft: NFT?) {
        self.nft = nft
    }
}

// MARK: - NftDetailsInteractorInput

extension NftDetailsInteractor: NftDetailsInteractorInput {
    func setup(with output: NftDetailsInteractorOutput) {
        self.output = output

        if let nft = nft {
            output.didReceive(nft: nft)
        }
    }
}
