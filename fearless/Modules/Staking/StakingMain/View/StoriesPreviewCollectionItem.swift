import UIKit
import SoraUI

class StoriesPreviewCollectionItem: UICollectionViewCell {

    @IBOutlet private var iconLabel: UILabel!
    @IBOutlet private var captionLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorHighlightedPink()
        self.selectedBackgroundView = selectedBackgroundView
    }

    func bind(icon: String?, caption: String?) {
        iconLabel.text = icon
        captionLabel.text = caption
    }
}
