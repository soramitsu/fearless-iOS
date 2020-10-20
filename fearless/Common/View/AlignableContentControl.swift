import Foundation
import SoraUI

class AlignableContentControl: BackgroundedContentControl {
    enum Alignment {
        case none
        case left
    }

    var alignment: Alignment = .left {
        didSet {
            setNeedsLayout()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard let contentView = contentView else { return }

        switch alignment {
        case .left:
            contentView.frame = CGRect(x: contentInsets.left,
                                       y: contentInsets.top,
                                       width: bounds.size.width - contentInsets.left - contentInsets.right,
                                       height: bounds.size.height - contentInsets.top - contentInsets.bottom)
        case .none:
            break
        }
    }
}
