import UIKit

@IBDesignable
open class TriangularedBlurView: UIView {
    private(set) var blurView: UIVisualEffectView?
    private(set) var blurMaskView: TriangularedView?
    private(set) var overlayView: TriangularedView!

    public override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)

        configure()
    }

    var sideLength: CGFloat = 10.0 {
        didSet {
            blurMaskView?.sideLength  = sideLength
            overlayView.sideLength = sideLength
        }
    }

    var cornerCut: TriangularedCorners = [.topLeft, .bottomRight] {
        didSet {
            blurMaskView?.cornerCut = cornerCut
            overlayView.cornerCut = cornerCut
        }
    }

    var blurStyle: UIBlurEffect.Style = .regular {
        didSet {
            removeBlurView()
            addBlurView()
            setNeedsLayout()
        }
    }

    open func configure() {
        backgroundColor = .clear

        addBlurView()
        addOverlayView()
    }

    private func addOverlayView() {
        if overlayView == nil {
            overlayView = TriangularedView()
            overlayView.cornerCut = cornerCut
            overlayView.sideLength = sideLength
            overlayView.shadowOpacity = 0.0
            overlayView.fillColor = .clear
            overlayView.highlightedFillColor = .clear
            addSubview(overlayView)
        }
    }

    private func removeBlurView() {
        blurView?.removeFromSuperview()
        blurView = nil
        blurMaskView = nil
    }

    private func addBlurView() {
        if blurView == nil {
            let blur = UIBlurEffect(style: blurStyle)
            let blurView = UIVisualEffectView(effect: blur)
            insertSubview(blurView, at: 0)

            self.blurView = blurView
        }

        if blurMaskView == nil {
            let blurMaskView = TriangularedView()
            blurMaskView.cornerCut = cornerCut
            blurMaskView.shadowOpacity = 0.0
            blurMaskView.fillColor = .black

            blurView?.mask = blurMaskView

            self.blurMaskView = blurMaskView
        }
    }

    open override func layoutSubviews() {
        super.layoutSubviews()

        blurMaskView?.frame = CGRect(origin: .zero, size: bounds.size)
        blurView?.frame = bounds
        overlayView.frame = bounds
    }
}
