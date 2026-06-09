/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

public final class LoadingView: UIView {
    private struct Constants {
        static let animationPath = "transform.rotation.z"
        static let animationKey = "loading.animation.key"
    }

    public var contentSize: CGSize {
        set(newValue) {
            contentViewWidthConstraint.constant = newValue.width
            contentViewHeightConstraint.constant = newValue.height
            setNeedsLayout()
        }

        get {
            return CGSize(width: contentViewWidthConstraint.constant,
                          height: contentViewHeightConstraint.constant)
        }
    }

    public var contentCornerRadius: CGFloat {
        set(newValue) {
            contentView.cornerRadius = newValue
        }

        get {
            return contentView.cornerRadius
        }
    }

    public var contentBackgroundColor: UIColor {
        set(newValue) {
            contentView.fillColor = newValue
        }

        get {
            return contentView.fillColor
        }
    }

    public var indicatorImage: UIImage? {
        set(newValue) {
            imageView.image = newValue
        }

        get {
            return imageView.image
        }
    }

    public var isAnimating: Bool = false

    public var animationDuration: TimeInterval = 1.0

    private var imageView: UIImageView!
    private var contentView: RoundedView!

    private var contentViewWidthConstraint: NSLayoutConstraint!
    private var contentViewHeightConstraint: NSLayoutConstraint!

    deinit {
        clearApplicationStateHandlers()
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    convenience public init(frame: CGRect, indicatorImage: UIImage) {
        self.init(frame: frame)

        self.indicatorImage = indicatorImage
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        configure()
    }

    private func configure() {
        configureContentView()
        configureImageView()
    }

    private func configureContentView() {
        contentView = RoundedView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.strokeWidth = 0.0
        contentView.shadowOpacity = 0.0
        addSubview(contentView)

        contentView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        contentView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true

        contentViewWidthConstraint = contentView.widthAnchor.constraint(equalToConstant: 120.0)
        contentViewHeightConstraint = contentView.heightAnchor.constraint(equalToConstant: 120.0)

        contentViewWidthConstraint.isActive = true
        contentViewHeightConstraint.isActive = true
    }

    private func configureImageView() {
        imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        imageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true
        imageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
    }

    public func startAnimating() {
        guard !isAnimating else {
            return
        }

        isAnimating = true

        let animation = createAnimation()
        imageView.layer.add(animation, forKey: Constants.animationKey)

        setupApplicationStateHandlers()
    }

    public func stopAnimating() {
        guard isAnimating else {
            return
        }

        imageView.layer.removeAnimation(forKey: Constants.animationKey)

        isAnimating = false

        clearApplicationStateHandlers()
    }

    public func createAnimation() -> CAAnimation {
        let animation = CAKeyframeAnimation(keyPath: Constants.animationPath)
        animation.values = [0.0, CGFloat.pi, 2.0 * CGFloat.pi]
        animation.timingFunctions = [CAMediaTimingFunction(name: .easeIn), CAMediaTimingFunction(name: .easeOut)]
        animation.calculationMode = .linear
        animation.keyTimes = [0.0, 0.5, 1.0]
        animation.repeatDuration = TimeInterval.infinity
        animation.duration = animationDuration
        animation.isCumulative = false
        return animation
    }

    // MARK: Application state handling

    private func setupApplicationStateHandlers() {
        clearApplicationStateHandlers()

        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                               object: nil,
                                               queue: OperationQueue.main) { [weak self] (_) in
                                                self?.resumeSnapshotAnimation()
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                               object: nil,
                                               queue: OperationQueue.main) { [weak self] (_) in
                                                self?.imageView.layer.removeAnimation(forKey: Constants.animationKey)
        }
    }

    private func clearApplicationStateHandlers() {
        NotificationCenter.default.removeObserver(self,
                                                  name: UIApplication.willEnterForegroundNotification,
                                                  object: nil)
    }

    private func resumeSnapshotAnimation() {
        if isAnimating {
            let animation = createAnimation()
            imageView.layer.add(animation, forKey: Constants.animationKey)
        }
    }

}
