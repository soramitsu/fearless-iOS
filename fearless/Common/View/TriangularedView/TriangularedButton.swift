import Foundation
import SoraUI
import UIKit
import SnapKit

/**
 *  Subclass of `BackgroundedContentControl` designed to provide button that contains
 *  triangulared background with shadows and content view consisting of title and icon.
 *
 *  Class supports `IBDesignable` protocol to provide appearance via Interface Builder.
 */
@IBDesignable
class TriangularedButton: BackgroundedContentControl {
    private var isLoading: Bool = false
    private(set) var wrappingLabel: UILabel?
    private var wrappingHeight: Constraint?
    private var wrappingMinimumHeight: CGFloat = 56
    private var wrappingLeading: Constraint?
    private var wrappingIcon: UIImageView?

    private var wrappingTextWidth: CGFloat {
        max(1, bounds.width - (wrappingIcon?.image == nil ? 32 : 68))
    }

    /// Keep this control's action/loading/disabled semantics while wrapping its title.
    func configureWrappingTitle(
        locale: Locale, compatibleWith traits: UITraitCollection, minimumHeight: CGFloat = 56
    ) {
        wrappingMinimumHeight = max(44, minimumHeight)
        if wrappingLabel == nil {
            let label = UILabel()
            label.numberOfLines = 0
            label.textAlignment = .center
            label.isUserInteractionEnabled = false
            label.isAccessibilityElement = false
            addSubview(label)
            label.snp.makeConstraints {
                $0.top.bottom.equalToSuperview().inset(14)
                $0.trailing.equalToSuperview().inset(16)
                wrappingLeading = $0.leading.equalToSuperview().offset(16).constraint
            }
            let icon = UIImageView()
            icon.contentMode = .scaleAspectFit
            icon.isAccessibilityElement = false
            addSubview(icon)
            icon.snp.makeConstraints {
                $0.leading.equalToSuperview().offset(16)
                $0.centerY.equalToSuperview()
                $0.size.equalTo(24)
            }
            wrappingIcon = icon
            wrappingLabel = label
            snp.makeConstraints { wrappingHeight = $0.height.equalTo(wrappingMinimumHeight).constraint }
        }
        wrappingIcon?.image = imageWithTitleView?.iconImage
        wrappingIcon?.isHidden = isLoading || wrappingIcon?.image == nil
        wrappingLeading?.update(offset: wrappingIcon?.image == nil ? 16 : 52)
        wrappingLabel?.text = imageWithTitleView?.title
        wrappingLabel?.font = .fw(.labelL, locale: locale, compatibleWith: traits)
        wrappingLabel?.textColor = imageWithTitleView?.titleColor
        imageWithTitleView?.isHidden = true
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override var intrinsicContentSize: CGSize {
        guard let label = wrappingLabel else { return super.intrinsicContentSize }
        let size = label.sizeThatFits(CGSize(width: wrappingTextWidth, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: max(wrappingMinimumHeight, ceil(size.height) + 28))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let label = wrappingLabel else { return }
        imageWithTitleView?.isHidden = true
        label.isHidden = isLoading
        wrappingIcon?.isHidden = isLoading || wrappingIcon?.image == nil
        label.textColor = imageWithTitleView?.titleColor
        let size = label.sizeThatFits(CGSize(width: wrappingTextWidth, height: .greatestFiniteMagnitude))
        wrappingHeight?.update(offset: max(wrappingMinimumHeight, ceil(size.height) + 28))
        let width = wrappingTextWidth
        if label.preferredMaxLayoutWidth != width {
            label.preferredMaxLayoutWidth = width
            invalidateIntrinsicContentSize()
        }
    }

    override var accessibilityLabel: String? {
        get { super.accessibilityLabel ?? imageWithTitleView?.title }
        set { super.accessibilityLabel = newValue }
    }

    override var accessibilityTraits: UIAccessibilityTraits {
        get {
            var traits = super.accessibilityTraits.union(.button)
            if !isEnabled || isLoading || !isUserInteractionEnabled {
                traits.insert(.notEnabled)
            }
            return traits
        }
        set { super.accessibilityTraits = newValue }
    }

    override func accessibilityActivate() -> Bool {
        guard isEnabled, !isLoading, isUserInteractionEnabled, !isHidden else { return false }
        sendActions(for: .touchUpInside)
        return true
    }

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

        return UIActivityIndicatorView(style: .medium)
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
        isAccessibilityElement = true

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

        if changeStyle, !isLoading {
            if isEnabled { applyEnabledStyle() } else { applyDisabledStyle() }
        }
    }

    func set(loading: Bool) {
        isLoading = loading
        imageWithTitleView?.isHidden = loading || wrappingLabel != nil
        wrappingLabel?.isHidden = loading
        wrappingIcon?.isHidden = loading || wrappingIcon?.image == nil
        isUserInteractionEnabled = !loading

        if loading {
            activityIndicator.startAnimating()
            applyDisabledStyle()
        } else {
            activityIndicator.stopAnimating()
            set(enabled: isEnabled, changeStyle: false)
        }
    }
}
