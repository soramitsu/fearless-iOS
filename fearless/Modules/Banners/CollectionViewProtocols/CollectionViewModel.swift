import UIKit

public protocol CollectionViewModel: NSObject {
    var cellType: UICollectionViewCell.Type { get }
}
