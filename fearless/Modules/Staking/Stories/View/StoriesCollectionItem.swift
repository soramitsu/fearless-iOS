import UIKit
import SoraUI

class StoriesCollectionItem: UICollectionViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentLabel: UILabel!
    @IBOutlet weak var learnMoreButton: TriangularedButton!
    @IBOutlet weak var progressView: UIView!

    private var story: Story?

    override func awakeFromNib() {
        super.awakeFromNib()

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorHighlightedPink()
        self.selectedBackgroundView = selectedBackgroundView
    }

    @IBAction func learnMoreButtonTouch() {
        #warning("Not Implemented")
    }

    func bind(title: String?, content: String?) {
        titleLabel.text = title
        contentLabel.text = content
    }

    func bind(_ story: Story) {
        self.story = story
        setupProgressView()
    }

    private func setupProgressView() {
        
    }
}
