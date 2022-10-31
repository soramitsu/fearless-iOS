import UIKit
import SoraUI

final class IconTitleHeaderView: UITableViewHeaderFooterView {
    var customBackgroundColor: UIColor?
    @IBOutlet private(set) var titleView: ImageWithTitleView!

    override func awakeFromNib() {
        super.awakeFromNib()

//Backward compatibility
        if customBackgroundColor != nil {
            backgroundColor = customBackgroundColor
        } else {
            let backgroundView = UIView()
            backgroundView.backgroundColor = R.color.colorBlack()
            self.backgroundView = backgroundView
        }
    }

    func bind(title: String, icon: UIImage?) {
        titleView.title = title
        titleView.iconImage = icon
        contentView.invalidateIntrinsicContentSize()
    }
}
