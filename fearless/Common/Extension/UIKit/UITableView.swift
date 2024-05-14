import Foundation
import UIKit

extension UITableView {
    func setAndLayoutTableHeaderView(header: UIView) {
        tableHeaderView = header
        tableHeaderView?.translatesAutoresizingMaskIntoConstraints = false
        tableHeaderView?.snp.makeConstraints { make in
            make.width.equalTo(self.frame.width)
        }
        header.setNeedsLayout()
        header.layoutIfNeeded()
        header.frame.size = header.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        tableHeaderView = header
    }
}
