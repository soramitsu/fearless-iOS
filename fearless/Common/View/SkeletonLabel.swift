import UIKit
import SoraUI

class SkeletonLabel: UILabel, SkeletonLoadableView {
    var container: UIView {
        self
    }

    var skeletonSize: CGSize
    var skeletonView: SkrullableView?

    init(skeletonSize: CGSize) {
        self.skeletonSize = skeletonSize
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateTextWithLoading(_ text: String?) {
        self.text = text

        if text != nil {
            stopSkeletonAnimation()
        } else {
            startSkeletonAnimation()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if text == nil {
            updateSkeletonLayout()
        }
    }
}
