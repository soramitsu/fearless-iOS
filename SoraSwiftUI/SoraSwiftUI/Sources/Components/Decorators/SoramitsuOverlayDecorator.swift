import UIKit

final class SoramitsuOverlayDecorator {
    
    public enum State {
        case inactive, aboveAll, aboveBackground
    }
    
    var state: State = .inactive {
        didSet {
            updateState()
        }
    }
    
    weak var view: UIView?
    
    private let style: SoramitsuStyle
    
    private lazy var overlayLayer: CALayer = {
        let layer = CALayer()
        layer.masksToBounds = true
        layer.backgroundColor = style.palette.color(.custom(uiColor: .clear)).cgColor
        return layer
    }()
    
    init(style: SoramitsuStyle) {
        self.style = style
        self.style.addObserver(self)
    }
    
    private func updateState() {
        guard let view = view else { return }
        UIView.transition(with: view,
                          duration: CATransaction.animationDuration(),
                          options: [.transitionCrossDissolve, .allowUserInteraction],
                          animations: {
            switch self.state {
            case .inactive:
                self.overlayLayer.removeFromSuperlayer()
            case .aboveBackground:
                view.layer.insertSublayer(self.overlayLayer, at: 0)
            case .aboveAll:
                view.layer.addSublayer(self.overlayLayer)
            }
        })
    }
    
    /// Размер вью изменился
    func viewSizeDidChange() {
        overlayLayer.frame = view?.bounds ?? .zero
    }
    
    /// Радиус закругления вью
    func viewCornerRadiusDidChange() {
        overlayLayer.cornerRadius = view?.layer.cornerRadius ?? 0
    }
}

extension SoramitsuOverlayDecorator: SoramitsuObserver {
    func styleDidChange(options: UpdateOptions) {
        if options.contains(.palette) {
            overlayLayer.backgroundColor = style.palette.color(.custom(uiColor: .clear)).cgColor
        }
    }
}
