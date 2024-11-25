import UIKit

final class CollectionTempDataSource: NSObject, UICollectionViewDataSource {
    // MARK: - Properties

    var data: [CollectionViewModel]

    // MARK: - Initialization

    init(
        data: [CollectionViewModel]
    ) {
        self.data = data
    }

    // MARK: - UICollectionViewDataSource

    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        data.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let model = data[indexPath.item]
        let cell = collectionView.dequeueReusableCellWithType(model.cellType, forIndexPath: indexPath) as? CollectionViewCell
        cell?.bind(viewModel: model)
        return cell ?? UICollectionViewCell()
    }
}
