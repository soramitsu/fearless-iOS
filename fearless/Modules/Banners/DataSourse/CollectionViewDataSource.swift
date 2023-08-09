import Foundation
import UIKit

final class CollectionViewDataSource<Cell: UICollectionViewCell, Model>: NSObject, UICollectionViewDataSource {
    // MARK: - Nested Types

    typealias CellConfigurator = (Model, Cell) -> Void

    var data: [Model]

    // MARK: - Pirivate Properties

    private var cellClass: Cell.Type
    private var cellConfigurator: CellConfigurator

    // MARK: - Initialization

    init(data: [Model], cellClass: Cell.Type, cellConfigurator: @escaping CellConfigurator) {
        self.data = data
        self.cellClass = cellClass
        self.cellConfigurator = cellConfigurator
    }

    // MARK: - UICollectionViewDataSource

    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        data.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithType(cellClass, forIndexPath: indexPath)
        let model = data[indexPath.item]
        cellConfigurator(model, cell)
        return cell
    }
}
