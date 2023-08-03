import Foundation
import UIKit

extension UITableView {
    func setAndLayoutTableHeaderView(header: UIView) {
        tableHeaderView = header
        tableHeaderView?.translatesAutoresizingMaskIntoConstraints = false
        header.snp.makeConstraints { make in
            make.width.equalToSuperview()
        }
        header.setNeedsLayout()
        header.layoutIfNeeded()
        header.frame.size = header.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        tableHeaderView = header
    }
}
