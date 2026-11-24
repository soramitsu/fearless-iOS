import UIKit

@IBDesignable
open class TriangularedBlurView: UIView {
    private(set) var blurView: UIVisualEffectView?
    private(set) var blurMaskView: TriangularedView?
    private(set) var overlayView: TriangularedView!

    override public init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)

        configure()
    }

    var sideLength: CGFloat = 10.0 {
        didSet {
            blurMaskView?.sideLength = sideLength
            overlayView.sideLength = sideLength
        }
    }

    var cornerCut: TriangularedCorners = [.topLeft, .bottomRight] {
        didSet {
            blurMaskView?.cornerCut = cornerCut
            overlayView.cornerCut = cornerCut
        }
    }

    var blurStyle: UIBlurEffect.Style = .dark {
        didSet {
            removeBlurView()
            addBlurView()
            blurView?.isHidden = true
            setNeedsLayout()
        }
    }

    open func configure() {
        backgroundColor = .clear

        addBlurView()
        addOverlayView()
        // Sun-lit redesign: cards are opaque Raised-1 surfaces lit by the key light, not live blur.
        blurView?.isHidden = true
        overlayView.fillColor = FWSunlit.Palette.background
        overlayView.highlightedFillColor = FWSunlit.Palette.backgroundDeep
        overlayView.fwElevation = .raised1
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
            blurMaskView.fwElevation = .flat

            blurView?.mask = blurMaskView

            self.blurMaskView = blurMaskView
        }
    }

    override open func layoutSubviews() {
        super.layoutSubviews()

        blurMaskView?.frame = CGRect(origin: .zero, size: bounds.size)
        blurView?.frame = bounds
        overlayView.frame = bounds
    }
}
