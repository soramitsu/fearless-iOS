import Foundation
import UIKit
import SoraUI

final class SelectedNetworkButton: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setDot()
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        clipsToBounds = true
    }

    override func setTitle(_ title: String?, for state: UIControl.State) {
        let fullString = NSMutableAttributedString(string: (title ?? "") + "  ")

        let imageAttachment = NSTextAttachment()
        imageAttachment.image = R.image.dropTriangle()
        imageAttachment.bounds = CGRect(
            x: 0,
            y: 3,
            width: 12,
            height: 6
        )

        let imageString = NSAttributedString(attachment: imageAttachment)
        fullString.append(imageString)

        setAttributedTitle(fullString, for: state)
    }

    override func imageRect(forContentRect contentRect: CGRect) -> CGRect {
        let rect = super.imageRect(forContentRect: contentRect)

        return CGRect(
            x: rect.minX - 6,
            y: rect.minY,
            width: rect.width,
            height: rect.height
        )
    }

    private func setup() {
        backgroundColor = R.color.colorWhite8()
        contentEdgeInsets = UIEdgeInsets(top: 2, left: 18, bottom: 2, right: 18)
    }

    private func setDot() {
        setImage(R.image.pinkDot(), for: .normal)
    }
}
