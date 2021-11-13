import UIKit

class AttentionView: HintView {
    override init(frame: CGRect) {
        super.init(frame: frame)

        iconView.image = R.image.iconAttention()
    }
}
