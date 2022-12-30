import Foundation
import UIKit

extension UITableViewCell {
    var usedTableView: UITableView? {
        next(of: UITableView.self)
    }

    var indexPath: IndexPath? {
        usedTableView?.indexPath(for: self)
    }
}
