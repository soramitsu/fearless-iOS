import UIKit

public final class PolkadotIconView: UIView {
    private(set) var icon: DrawableIcon?

    public var fillColor: UIColor = .white {
        didSet {
            setNeedsDisplay()
        }
    }

    public func bind(icon: DrawableIcon) {
        self.icon = icon

        setNeedsDisplay()
    }

    override public func draw(_ rect: CGRect) {
        super.draw(rect)

        if let context = UIGraphicsGetCurrentContext() {
            icon?.drawInContext(context, fillColor: fillColor, size: rect.size)
        }
    }
}
