import UIKit

public protocol CollectionViewCell: UICollectionViewCell {
    func bind(viewModel: CollectionViewModel)
}
