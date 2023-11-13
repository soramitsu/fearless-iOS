import UIKit

final class NftCollectionInteractor {
    // MARK: - Private properties

    private weak var output: NftCollectionInteractorOutput?
    private var collection: NFTCollection

    init(collection: NFTCollection) {
        self.collection = collection
    }
}

// MARK: - NftCollectionInteractorInput

extension NftCollectionInteractor: NftCollectionInteractorInput {
    func setup(with output: NftCollectionInteractorOutput) {
        self.output = output

        output.didReceive(collection: collection)
    }
}
