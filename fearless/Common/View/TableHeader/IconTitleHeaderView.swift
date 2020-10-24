import UIKit
import SoraUI

final class IconTitleHeaderView: UITableViewHeaderFooterView {
    @IBOutlet private var titleView: ImageWithTitleView!

    override func awakeFromNib() {
        super.awakeFromNib()

        let backgroundView = UIView()
        backgroundView.backgroundColor = R.color.colorBlack()!
        self.backgroundView = backgroundView
    }

    func bind(title: String, icon: UIImage?) {
        titleView.title = title
        titleView.iconImage = icon
        contentView.invalidateIntrinsicContentSize()
    }
}
