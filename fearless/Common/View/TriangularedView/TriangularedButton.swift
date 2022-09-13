import Foundation
import SoraUI
import UIKit

/**
 *  Subclass of `BackgroundedContentControl` designed to provide button that contains
 *  triangulared background with shadows and content view consisting of title and icon.
 *
 *  Class supports `IBDesignable` protocol to provide appearance via Interface Builder.
 */
@IBDesignable
class TriangularedButton: BackgroundedContentControl {
    /// Returns content view that consists of title and icon
    public var imageWithTitleView: ImageWithTitleView? {
        contentView as? ImageWithTitleView
    }

    /// Returns backround view with cut corners
    var triangularedView: TriangularedView? {
        backgroundView as? TriangularedView
    }

    lazy var activityIndicator: UIActivityIndicatorView = {
        if #available(iOS 13, *) {
            return UIActivityIndicatorView(style: .medium)
        }

        return UIActivityIndicatorView(style: .white)
    }()

    // MARK: Overriden initializers

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    override open func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        configure()
    }

    /**
         Creates and setups content and background views. This method **must not** be called
         directly but can be overriden by subclass.
     */
    open func configure() {
        backgroundColor = UIColor.clear

        if backgroundView == nil {
            backgroundView = TriangularedView()
            backgroundView?.isUserInteractionEnabled = false
        }

        if contentView == nil {
            contentView = ImageWithTitleView()
            contentView?.isUserInteractionEnabled = false
        }

        addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
        }
    }

    func set(enabled: Bool, changeStyle: Bool = true) {
        isEnabled = enabled

        if changeStyle {
            isEnabled ? applyEnabledStyle() : applyDisabledStyle()
        }
    }

    func set(loading: Bool) {
        if loading {
            activityIndicator.startAnimating()
            applyLoadingStyle()
        } else {
            activityIndicator.stopAnimating()
            applyEnabledStyle()
        }
    }
}
