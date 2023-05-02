import UIKit

class VerticalContentButton: UIButton {
    enum LayoutConstants {
        static let verticalOffset: CGFloat = 10
    }

    override func titleRect(forContentRect contentRect: CGRect) -> CGRect {
        let rect = super.titleRect(forContentRect: contentRect)

        return CGRect(
            x: 0,
            y: (contentRect.height / 2) + (rect.height / 2) + LayoutConstants.verticalOffset,
            width: contentRect.width,
            height: rect.height
        )
    }

    override func imageRect(forContentRect contentRect: CGRect) -> CGRect {
        let rect = super.imageRect(forContentRect: contentRect)

        return CGRect(
            x: contentRect.width / 2 - rect.width / 2,
            y: (contentRect.height / 2) - (rect.height / 2) - LayoutConstants.verticalOffset,
            width: rect.width,
            height: rect.height
        )
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize

        if let image = imageView?.image {
            var labelHeight: CGFloat = 0

            if let size = titleLabel?
                .sizeThatFits(CGSize(
                    width: self.contentRect(forBounds: self.bounds).width,
                    height: CGFloat.greatestFiniteMagnitude
                )) {
                labelHeight = size.height
            }

            return CGSize(
                width: size.width,
                height: image.size.height + labelHeight + 5
            )
        }

        return size
    }

    override var isEnabled: Bool {
        didSet {
            isEnabled
                ? setTitleColor(R.color.colorWhite(), for: .normal)
                : setTitleColor(R.color.colorGray(), for: .normal)
        }
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
