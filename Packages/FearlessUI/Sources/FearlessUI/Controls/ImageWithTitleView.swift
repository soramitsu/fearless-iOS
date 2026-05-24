/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

/**
    Class is designed to provide commonly used element containing image and title.
    Image View and Title Label are lazily created when of their related properties are set.
    Implementation supports @IBDesignable protocol which allows native design through Interface Builder.
 */

@IBDesignable
public class ImageWithTitleView: UIView, Highlightable {

    /// Type that describes how image and title are placed relatively to each other
    public enum LayoutType: UInt8 {
        /// image and then title are placed from left to right
        case horizontalImageFirst = 0
        /// title and then image are placed from left to right
        case horizontalLabelFirst = 1
        /// image and then title are placed from top to bottom
        case verticalImageFirst = 2
        /// title and then image are placed from top to bottom
        case verticalLabelFirst = 3
    }

    // MARK: Public properties

    /**
        Flags that states where the image and title should be highlighted.
        This property is visible and can be setup through Interface Builder.
        By default is `false`.
    */
    @IBInspectable
    open var isHighlighted: Bool = false {
        didSet {
            titleLabel?.isHighlighted = isHighlighted
            imageView?.isHighlighted = isHighlighted
        }
    }

    /// Duration of highlight animation
    open var highlightableAnimationDuration: TimeInterval = 0.5

    // Additional options of highligh animation
    open var highlightableAnimationOptions: UIView.AnimationOptions = UIView.AnimationOptions.curveEaseOut

    // Starting alha value to animate highlighted cross dissolve
    open var highlightedCrossDissolveAlpha: CGFloat = 0.5

    /// Highlightable protocol implementation that is used to animate highlighted state changes
    open func set(highlighted: Bool, animated: Bool) {
        if animated {
            self.isHighlighted = !highlighted
            self.alpha = highlightedCrossDissolveAlpha
            UIView.animate(withDuration: highlightableAnimationDuration,
                           delay: 0.0,
                           options: highlightableAnimationOptions,
                           animations: {
                            self.alpha = 1.0
                            self.isHighlighted = highlighted
            }, completion: { _ in
                self.alpha = 1.0
            })
        } else {
            isHighlighted = highlighted
        }
    }

    /**
        Controls spacing between the image and the title. The valye is applied only if both
        the image and the title are presented.
        The property is visible and can be setup through Interface Builder.
        Default value is `8.0`.
    */
    @IBInspectable
    open var spacingBetweenLabelAndIcon: CGFloat = 8.0

    /**
        Controls displacing of the right (bottom) view relatively to left (top) view.
        By default there is no displacement.
    */
    @IBInspectable
    open var displacementBetweenLabelAndIcon: CGFloat = 0.0

    /**
        Controls layout which applied to the image and the title when both are presented.
        Default value is `.horizontalImageFirst`
    */
    open var layoutType: LayoutType = LayoutType.horizontalImageFirst

    /// Control font of the title displayed. By default standard label font is set
    open var titleFont: UIFont? {
        set(newValue) {
            configureTitleLabelIfNeeded()
            titleLabel?.font = newValue
            invalidateLayout()
        }

        get { return titleLabel?.font }
    }

    /// String to display as the title. Layout is automatically updated when this property changes.
    @IBInspectable
    open var title: String? {
        set(newValue) {
            configureTitleLabelIfNeeded()
            titleLabel?.text = newValue
            invalidateLayout()
        }

        get { return titleLabel?.text }
    }

    /// Title color to apply in normal state.
    @IBInspectable
    open var titleColor: UIColor? {
        set(newValue) {
            configureTitleLabelIfNeeded()
            titleLabel?.textColor = newValue
        }

        get { return titleLabel?.textColor }
    }

    /// Title color to apply in highlighted state.
    @IBInspectable
    open var highlightedTitleColor: UIColor? {
        set(newValue) {
            configureTitleLabelIfNeeded()
            titleLabel?.highlightedTextColor = newValue
        }

        get {
            return titleLabel?.highlightedTextColor
        }
    }

    /// Icon image to display in normal state. Layout is automatically updated when this property changes.
    @IBInspectable
    open var iconImage: UIImage? {
        set(newValue) {
            configureImageViewIfNeeded()
            imageView?.image = newValue
            invalidateLayout()
        }

        get {
            return imageView?.image
        }
    }

    /**
        Icon image to display in highlighted state. To avoid layout problems highlighted image must be
        the same size as normal one.
        Layout is automatically updated when this property changes.
    */
    @IBInspectable
    open var highlightedIconImage: UIImage? {
        set(newValue) {
            configureImageViewIfNeeded()
            imageView?.highlightedImage = newValue
            invalidateLayout()
        }

        get {
            return imageView?.highlightedImage
        }
    }

    /**
        Icon tint color to display.
    */
    @IBInspectable
    open var iconTintColor: UIColor? {
        set(newValue) {
            imageView?.tintColor = newValue
        }

        get {
            return imageView?.tintColor
        }
    }

    // MARK: Private properties

    private weak var titleLabel: UILabel? {
        willSet {
            guard let currentLabel = titleLabel else { return }

            if currentLabel != newValue { currentLabel.removeFromSuperview() }

            invalidateLayout()
        }

        didSet {
            guard let existingLabel = titleLabel else { return }

            existingLabel.isHighlighted = isHighlighted

            if existingLabel.superview != self { self.addSubview(existingLabel) }

            invalidateLayout()
        }
    }

    private weak var imageView: UIImageView? {
        willSet {
            guard let currentImageView = imageView else { return }

            if currentImageView != imageView { currentImageView.removeFromSuperview() }

            invalidateLayout()
        }

        didSet {
            guard let existingImageView = imageView else { return }

            existingImageView.isHighlighted = isHighlighted

            if existingImageView.superview != self { self.addSubview(existingImageView) }

            invalidateLayout()
        }
    }

    // MARK: Overriden methods

    override open var intrinsicContentSize: CGSize {
        if titleLabel != nil && imageView == nil {
            let width = titleLabel!.intrinsicContentSize.width
            let height = titleLabel!.intrinsicContentSize.height
            return CGSize(width: width, height: height)
        }

        if titleLabel == nil && imageView != nil {
            let width = imageView!.intrinsicContentSize.width
            let height = imageView!.intrinsicContentSize.height
            return CGSize(width: width, height: height)
        }

        if titleLabel != nil && imageView != nil {
            let imageViewSize = imageView!.intrinsicContentSize
            let titleLabelSize = titleLabel!.intrinsicContentSize

            switch layoutType {
            case .horizontalImageFirst, .horizontalLabelFirst:
                let width = imageViewSize.width + titleLabelSize.width + spacingBetweenLabelAndIcon
                let height = max(imageViewSize.height, titleLabelSize.height)
                return CGSize(width: width, height: height)
            case .verticalImageFirst, .verticalLabelFirst:
                let width = max(imageViewSize.width, titleLabelSize.width)
                let height = imageViewSize.height + titleLabelSize.height + spacingBetweenLabelAndIcon
                return CGSize(width: width, height: height)
            }
        }

        return CGSize.zero
    }

    // MARK: Layout logic
    private func invalidateLayout() {
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override open func layoutSubviews() {
        super.layoutSubviews()

        if titleLabel != nil && imageView == nil {
            layoutOnlyItem(view: titleLabel!)
            return
        }

        if titleLabel == nil && imageView != nil {
            layoutOnlyItem(view: imageView!)
            return
        }

        if titleLabel != nil && imageView != nil {
            switch layoutType {
            case .horizontalImageFirst:
                layoutPairOfItemsHorizontally(firstView: imageView!, secondView: titleLabel!)
            case .horizontalLabelFirst:
                layoutPairOfItemsHorizontally(firstView: titleLabel!, secondView: imageView!)
            case .verticalImageFirst:
                layoutPairOfItemsVertically(firstView: imageView!, secondView: titleLabel!)
            case .verticalLabelFirst:
                layoutPairOfItemsVertically(firstView: titleLabel!, secondView: imageView!)
            }
        }
    }

    private func layoutOnlyItem(view: UIView) {
        view.frame = CGRect(origin: CGPoint.zero, size: view.intrinsicContentSize)
        view.center = CGPoint(x: Int(bounds.width / 2.0), y: Int(bounds.height / 2.0))
    }

    private func layoutPairOfItemsHorizontally(firstView: UIView, secondView: UIView) {
        let boundsSize = self.bounds.size
        let contentSize = self.intrinsicContentSize

        let firstViewSize = firstView.intrinsicContentSize
        let firstViewX = Int(boundsSize.width / 2.0 - contentSize.width / 2.0)
        let firstViewY = Int(boundsSize.height / 2.0 - firstViewSize.height / 2.0)
        firstView.frame = CGRect(origin: CGPoint(x: firstViewX, y: firstViewY), size: firstViewSize)

        let secondViewSize = secondView.intrinsicContentSize
        let secondViewX = CGFloat(Int(boundsSize.width / 2.0 + contentSize.width / 2.0 - secondViewSize.width))
        let secondViewY = CGFloat(Int(boundsSize.height / 2.0 - secondViewSize.height / 2.0))
            + displacementBetweenLabelAndIcon
        secondView.frame = CGRect(origin: CGPoint(x: secondViewX, y: secondViewY), size: secondViewSize)
    }

    private func layoutPairOfItemsVertically(firstView: UIView, secondView: UIView) {
        let boundsSize = self.bounds.size
        let contentSize = self.intrinsicContentSize

        let firstViewSize = firstView.intrinsicContentSize
        let firstViewX = Int(boundsSize.width / 2.0 - firstViewSize.width / 2.0)
        let firstViewY = Int(boundsSize.height / 2.0 - contentSize.height / 2.0)
        firstView.frame = CGRect(origin: CGPoint(x: firstViewX, y: firstViewY), size: firstViewSize)

        let secondViewSize = secondView.intrinsicContentSize
        let secondViewX = CGFloat(Int(boundsSize.width / 2.0 - secondViewSize.width / 2.0))
            + displacementBetweenLabelAndIcon
        let secondViewY = CGFloat(Int(boundsSize.height / 2.0 + contentSize.height / 2.0 - secondViewSize.height))
        secondView.frame = CGRect(origin: CGPoint(x: secondViewX, y: secondViewY), size: secondViewSize)
    }

    // MARK: Configuration logic

    private func configureTitleLabelIfNeeded() {
        if titleLabel == nil {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: UIFont.labelFontSize)
            label.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview(label)
            self.titleLabel = label
        }
    }

    private func configureImageViewIfNeeded() {
        if imageView == nil {
            let aImageView = UIImageView()
            aImageView.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview(aImageView)
            self.imageView = aImageView
        }
    }
}

/** ImageWithTitleView extension to provide access to properties which are not directly
 *  inspectable through Interface Builder.
 */
extension ImageWithTitleView {
    @IBInspectable
    private var _titleFontName: String? {
        set(newValue) {
            guard let fontName = newValue else {
                self.titleFont = nil
                return
            }

            guard let pointSize = self.titleLabel?.font.pointSize else {
                self.titleFont = UIFont(name: fontName, size: UIFont.buttonFontSize)
                return
            }

            self.titleFont = UIFont(name: fontName, size: pointSize)
        }

        get {
            return self.titleFont?.fontName
        }
    }

    @IBInspectable
    private var _titleFontSize: CGFloat {
        set(newValue) {
            guard let fontName = self.titleFont?.fontName else {
                self.titleFont = UIFont.systemFont(ofSize: newValue)
                return
            }

            self.titleFont = UIFont(name: fontName, size: newValue)
        }

        get {
            if let pointSize = self.titleFont?.pointSize {
                return pointSize
            } else {
                return 0.0
            }
        }
    }

    @IBInspectable
    private var _layoutType: UInt8 {
        set {
            guard let layoutType = LayoutType(rawValue: newValue) else {
                return
            }

            self.layoutType = layoutType
        }

        get {
            return layoutType.rawValue
        }
    }
}
