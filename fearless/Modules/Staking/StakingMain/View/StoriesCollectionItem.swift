import UIKit
import SoraUI

class StoriesCollectionItem: UICollectionViewCell {

    @IBOutlet private var iconLabel: UILabel!
    @IBOutlet private var captionLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        layer.masksToBounds = true
        layer.cornerRadius = 4.0
        layer.borderWidth = 1.0
        layer.borderColor = UIColor.init(white: 1.0, alpha: 0.5).cgColor

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorHighlightedPink()
        self.selectedBackgroundView = selectedBackgroundView
    }

    func bind(icon: String?, caption: String?) {
        iconLabel.text = icon
        captionLabel.text = caption
    }
}
