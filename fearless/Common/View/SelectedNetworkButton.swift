import Foundation
import UIKit
import SoraUI

final class SelectedNetworkButton: UIButton {
    private enum Constants {
        static let verticvalInset: CGFloat = 2
        static let horizontalInset: CGFloat = 18
        static let imageVerticalPosition: CGFloat = 3
        static let imageWidth: CGFloat = 12
        static let imageHeight: CGFloat = 6
    }

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
            y: Constants.imageVerticalPosition,
            width: Constants.imageWidth,
            height: Constants.imageHeight
        )

        let imageString = NSAttributedString(attachment: imageAttachment)
        fullString.append(imageString)

        setAttributedTitle(fullString, for: state)
    }

    override func imageRect(forContentRect contentRect: CGRect) -> CGRect {
        let rect = super.imageRect(forContentRect: contentRect)

        return CGRect(
            x: rect.minX - Constants.imageWidth / 2,
            y: rect.minY,
            width: rect.width,
            height: rect.height
        )
    }

    private func setup() {
        backgroundColor = R.color.colorWhite8()
        contentEdgeInsets = UIEdgeInsets(
            top: Constants.verticvalInset,
            left: Constants.horizontalInset,
            bottom: Constants.verticvalInset,
            right: Constants.horizontalInset
        )
    }

    private func setDot() {
        setImage(R.image.pinkDot(), for: .normal)
    }
}
