import UIKit
import SoraUI

class StoriesPreviewCollectionItem: UICollectionViewCell {

    @IBOutlet private var iconLabel: UILabel!
    @IBOutlet private var captionLabel: UILabel!
    @IBOutlet weak var strokeView: RoundedView!

    override var isHighlighted: Bool {
        willSet {
            strokeView.set(highlighted: newValue, animated: false)
        }
    }

    func bind(icon: String?, caption: String?) {
        iconLabel.text = icon
        captionLabel.text = caption
    }
}
