import UIKit
import SoraUI

final class IconTitleHeaderView: UITableViewHeaderFooterView {
    var customBackgroundColor: UIColor?
    @IBOutlet private(set) var titleView: ImageWithTitleView!

    func bind(title: String, icon: UIImage?) {
        titleView.title = title
        titleView.iconImage = icon
        contentView.invalidateIntrinsicContentSize()

        // UIKit ignores backgroundColor on a header-footer view, so a custom colour goes on the background view too.
        let backgroundView = UIView()
        backgroundView.backgroundColor = customBackgroundColor ?? R.color.colorBlack()
        self.backgroundView = backgroundView
    }
}
