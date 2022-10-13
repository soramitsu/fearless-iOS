import UIKit

extension UITableView {
    func scrollToLastSection() {
        scrollToRow(at: IndexPath(row: 0, section: numberOfSections - 1), at: .bottom, animated: true)
    }
}
