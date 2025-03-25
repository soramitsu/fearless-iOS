import Foundation
import UIKit

extension UITableView {
    func setAndLayoutTableHeaderView(header: UIView) {
        tableHeaderView = header
        header.translatesAutoresizingMaskIntoConstraints = false
        
        header.setNeedsLayout()
        header.layoutIfNeeded()
        header.frame.size = header.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        tableHeaderView = header
        
        header.snp.remakeConstraints { make in
            make.width.equalTo(self.frame.width-32)
            make.leading.equalToSuperview().inset(16)
        }
    }
}
