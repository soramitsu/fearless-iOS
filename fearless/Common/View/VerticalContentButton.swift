import UIKit

class VerticalContentButton: UIButton {
    override func titleRect(forContentRect contentRect: CGRect) -> CGRect {
        let rect = super.titleRect(forContentRect: contentRect)

        return CGRect(
            x: 0,
            y: contentRect.height - rect.height + 5,
            width: contentRect.width,
            height: rect.height
        )
    }

    override func imageRect(forContentRect contentRect: CGRect) -> CGRect {
        let rect = super.imageRect(forContentRect: contentRect)
        let titleRect = self.titleRect(forContentRect: contentRect)

        return CGRect(
            x: contentRect.width / 2.0 - rect.width / 2.0,
            y: (contentRect.height - titleRect.height) / 2.0 - rect.height / 2.0,
            width: rect.width,
            height: rect.height
        )
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize

        if let image = imageView?.image {
            var labelHeight: CGFloat = 0.0

            if let size = titleLabel?.sizeThatFits(CGSize(width: self.contentRect(forBounds: self.bounds).width, height: CGFloat.greatestFiniteMagnitude)) {
                labelHeight = size.height
            }

            return CGSize(width: size.width, height: image.size.height + labelHeight + 5)
        }

        return size
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        centerTitleLabel()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        centerTitleLabel()
    }

    private func centerTitleLabel() {
        titleLabel?.textAlignment = .center
    }
}
