import UIKit
import QuartzCore
import Foundation


public final class SoramitsuActivityIndicatorView: UIView, Atom {
    
    private struct Constants {
        static let animationCicleDuration: Double = 0.75
        static let strokeEndSelector = #selector(getter:CAShapeLayer.strokeEnd)
    }
    
    public let sora: SoramitsuActivityIndicatorViewConfiguration<SoramitsuActivityIndicatorView>
    
    public private(set) var isAnimating = false
    
    private var shouldStartAnimatingWhenMovedToWindow = false
    
    let indicatorLayer: CAShapeLayer = {
        let indicator = CAShapeLayer()
        indicator.fillColor = UIColor.clear.cgColor
        indicator.strokeEnd = 0
        indicator.lineCap = .round
        return indicator
    }()
    
    private var deferredWorkItem: DispatchWorkItem?
    
    private var lastStartTime = Date.distantPast
    
    public override var intrinsicContentSize: CGSize {
        return sora.size
    }
    
    init(style: SoramitsuStyle) {
        sora = SoramitsuActivityIndicatorViewConfiguration(style: style)
        super.init(frame: CGRect(origin: .zero, size: sora.size))
        isHidden = true
        layer.addSublayer(indicatorLayer)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
        sora.owner = self
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        indicatorLayer.frame = CGRect(origin: CGPoint(x: (bounds.width - sora.size.width) / 2 ,
                                                      y: (bounds.height - sora.size.height) / 2),
                                      size: sora.size)
    }
    
    public func startAnimating() {
        if window == nil {
            shouldStartAnimatingWhenMovedToWindow = true
            return
        }
        if isAnimating {
            return
        }
        isAnimating = true
        isHidden = false
        lastStartTime = Date()
        let strokeEnd = CABasicAnimation(propertySelector: Constants.strokeEndSelector,
                                         duration: Constants.animationCicleDuration * .pi / 2,
                                         toValue: 1)
        strokeEnd.autoreverses = true
        strokeEnd.repeatCount = .greatestFiniteMagnitude
        strokeEnd.isRemovedOnCompletion = false
        indicatorLayer.add(strokeEnd, forKey: NSStringFromSelector(Constants.strokeEndSelector))
        let rotation = CABasicAnimation(keyPath: "transform.rotation")
        rotation.fromValue = 0
        rotation.toValue = 2 * Float.pi
        rotation.duration = Constants.animationCicleDuration
        rotation.repeatCount = .greatestFiniteMagnitude
        rotation.isRemovedOnCompletion = false
        indicatorLayer.add(rotation, forKey: "rotation")
        UIView.animate(withDuration: CATransaction.animationDuration()) {
            self.alpha = 1
        }
    }
    
    public func startAnimating(delay: TimeInterval) {
        self.deferredWorkItem?.cancel()
        isAnimating = true
        let deferredWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.isAnimating else { return }
            self.deferredWorkItem = nil
            self.startAnimating()
        }
        self.deferredWorkItem = deferredWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: deferredWorkItem)
    }
    
    public func stopAnimating(completion: (() -> Void)? = nil) {
        self.shouldStartAnimatingWhenMovedToWindow = false
        if !self.isAnimating {
            return
        }
        DispatchQueue.main.async {
            let animations = {
                self.alpha = 0
            }
            let completion: (Bool) -> Void = { _ in
                self.isAnimating = false
                self.isHidden = true
                self.indicatorLayer.removeAllAnimations()
                completion?()
            }
            UIView.animate(withDuration: CATransaction.animationDuration(),
                           animations: animations,
                           completion: completion)
        }
    }
    
    public func stopAnimating(minimumDuration: TimeInterval) {
        let animatingTime = Date().timeIntervalSince(lastStartTime)
        if animatingTime > minimumDuration {
            stopAnimating()
        } else {
            self.deferredWorkItem?.cancel()
            let deferredWorkItem = DispatchWorkItem { [weak self] in
                guard let self = self, self.isAnimating else { return }
                self.deferredWorkItem = nil
                self.stopAnimating()
            }
            self.deferredWorkItem = deferredWorkItem
            DispatchQueue.main.asyncAfter(deadline: .now() + minimumDuration - animatingTime,
                                          execute: deferredWorkItem)
        }
    }
    
    public func pauseAndSetProgress(_ progress: CGFloat) {
        let progress = clamp(progress, minValue: 0, maxValue: 1)
        indicatorLayer.speed = 0
        indicatorLayer.timeOffset = CFTimeInterval(progress)
    }
    
    public func resumeAnimation() {
        let pausedTime = indicatorLayer.timeOffset
        
        indicatorLayer.strokeColor = sora.palette.color(.accentPrimary).cgColor
        indicatorLayer.speed = 1
        indicatorLayer.timeOffset = 0
        indicatorLayer.beginTime = 0
        
        let timeSincePause = layer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
        indicatorLayer.beginTime = timeSincePause
    }
    
    public override func didMoveToWindow() {
        if window != nil && shouldStartAnimatingWhenMovedToWindow {
            startAnimating()
            shouldStartAnimatingWhenMovedToWindow = false
        }
    }
    
    @objc private func applicationWillEnterForeground() {
        guard
            isAnimating,
            deferredWorkItem == nil else { return }
        startAnimating()
    }
}

public extension SoramitsuActivityIndicatorView {
    
    /// Инициализатор
    convenience init() {
        self.init(style: SoramitsuUI.shared.style)
    }
    
    class func expandableIndicator(with backgroundColor: SoramitsuColor = .accentPrimary, frame: CGRect) -> SoramitsuActivityIndicatorView {
        let indicator = SoramitsuActivityIndicatorView()
        indicator.sora.useAutoresizingMask = true
        indicator.frame = frame
        indicator.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        indicator.sora.backgroundColor = backgroundColor
        return indicator
    }
}

extension SoramitsuActivityIndicatorView: SoramitsuLoadingIndicatable {
    public func start() {
        resumeAnimation()
        startAnimating()
    }
    
    public func set(progress: CGFloat) {
        startAnimating()
        pauseAndSetProgress(progress)
    }
    
    public func stop() {
        stopAnimating()
    }
}
