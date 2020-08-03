import SoraUI

final class PlusIndicatorView: ActionControlIndicatorView {
    private let verticalView: UIView = UIView()
    private let horizontalView: UIView = UIView()

    var preferredSize: CGSize = CGSize(width: 20.0, height: 20.0) {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var strokeWidth: CGFloat = 2.0 {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var strokeColor: UIColor = .white {
        didSet {
            verticalView.backgroundColor = strokeColor
            horizontalView.backgroundColor = strokeColor
        }
    }

    var isActivated: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        configure()
    }

    private func configure() {
        if verticalView.superview == nil {
            verticalView.backgroundColor = strokeColor
            addSubview(verticalView)
        }

        if horizontalView.superview == nil {
            horizontalView.backgroundColor = strokeColor
            addSubview(horizontalView)
        }
    }

    // MARK: Overriding

    override var intrinsicContentSize: CGSize { preferredSize }

    override func layoutSubviews() {
        super.layoutSubviews()

        verticalView.transform = .identity

        verticalView.frame = CGRect(x: bounds.midX - strokeWidth / 2.0,
                                    y: bounds.minY,
                                    width: strokeWidth,
                                    height: bounds.width)

        horizontalView.frame = CGRect(x: bounds.minX,
                                      y: bounds.midY - strokeWidth / 2.0,
                                      width: bounds.width,
                                      height: strokeWidth)

        if isActivated {
            verticalView.transform = CGAffineTransform(rotationAngle: CGFloat.pi / 2.0)
        }
    }
}

extension PlusIndicatorView {
    func activate() {
        isActivated = true

        verticalView.transform = CGAffineTransform(rotationAngle: CGFloat.pi / 2.0)
    }

    func deactivate() {
        isActivated = false

        verticalView.transform = .identity
    }
}
