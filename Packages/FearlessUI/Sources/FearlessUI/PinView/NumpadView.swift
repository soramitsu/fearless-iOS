/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

public protocol NumpadViewDelegate: AnyObject {
    func numpadView(_ view: NumpadView, didSelectNumAt index: Int)
    func numpadViewDidSelectBackspace(_ view: NumpadView)
    func numpadViewDidSelectAccessoryControl(_ view: NumpadView)
}

public protocol NumpadAccessibilitySupportProtocol: AnyObject {
    func setupKeysAccessibilityIdWith(format: String?)
    func setupBackspace(accessibilityId: String?)
    func setupAccessory(accessibilityId: String?)
}

/**
 *  Subclass of UIView designed to represent numpad keyboard that can be used as an input for pincodes.
 */

@IBDesignable
open class NumpadView: UIView {
    private static let numberOfRows = 4
    private static let numberOfColums = 3

    /// By default the same as for `RoundedButton`
    public var fillColor: UIColor? {
        set(newValue) {
            guard let color = newValue else { return }
            applyNumFillColor(color)
        }

        get { return anyNumBackgroundView()?.fillColor }
    }

    /// By default the same as for `RoundedButton`
    public var highlightedFillColor: UIColor? {
        set(newValue) {
            guard let color = newValue else { return }
            applyNumHighlightedFillColor(color)
        }

        get { return anyNumBackgroundView()?.highlightedFillColor}
    }

    /// By default the same as for `RoundedButton`
    public var titleColor: UIColor? {
        set(newValue) {
            guard let color = newValue else { return }
            applyNumTitleColor(color)
        }

        get { return anyNumTitleView()?.titleColor }
    }

    /// By default the same as for `RoundedButton`
    public var titleFont: UIFont? {
        set(newValue) {
            guard let font = newValue else { return }
            applyNumFont(font)
        }

        get { return anyNumTitleView()?.titleFont }
    }

    /// By default the same as for `RoundedButton`
    public var highlightedTitleColor: UIColor? {
        set(newValue) {
            guard let color = newValue else { return }
            applyNumHighlightedTitleColor(color)
        }

        get { return anyNumTitleView()?.highlightedTitleColor }
    }

    /// By default the same as for `RoundedButton`
    @IBInspectable
    public var shadowOpacity: Float {
        set(newValue) {
            applyShadowOpacity(newValue)
        }

        get { return anyNumBackgroundView()?.shadowOpacity ?? 0.0 }
    }

    /// By default the same as for `RoundedButton`
    @IBInspectable
    public var shadowColor: UIColor? {
        set(newValue) {
            guard let color = newValue else { return }
            applyShadowColor(color)
        }

        get { return anyNumBackgroundView()?.shadowColor }
    }

    /// By default the same as for `RoundedButton`
    @IBInspectable
    public var shadowRadius: CGFloat {
        set(newValue) {
            applyShadowRadius(newValue)
        }

        get { return anyNumBackgroundView()?.shadowRadius ?? 0.0 }
    }

    /// By default the same as for `RoundedButton`
    @IBInspectable
    public var shadowOffset: CGSize {
        set(newValue) {
            applyShadowOffset(newValue)
        }

        get { return anyNumBackgroundView()?.shadowOffset ?? CGSize.zero }
    }

    /// By default no icon
    public var backspaceIcon: UIImage? {
        set(newValue) {
            _backspaceButton?.imageWithTitleView?.iconImage = newValue
            _backspaceButton?.invalidateLayout()
        }

        get { return _backspaceButton?.imageWithTitleView?.iconImage }
    }

    /// By default the same one as for normal state if exits
    public var backspaceHighlightedIcon: UIImage? {
        set(newValue) {
            _backspaceButton?.imageWithTitleView?.highlightedIconImage = newValue
            _backspaceButton?.invalidateLayout()
        }

        get { return _backspaceButton?.imageWithTitleView?.highlightedIconImage }
    }

    /**
     *  Icon to display on accessory control when enabled. By default nil.
     */
    public var accessoryIcon: UIImage? {
        didSet {
            _accessoryButton?.imageWithTitleView?.iconImage = accessoryIcon
            _accessoryButton?.invalidateLayout()
        }
    }

    /**
     *  Icon to display on accessory control when highlighted. By default nil.
     */
    public var accessoryHighlightedIcon: UIImage? {
        didSet {
            _accessoryButton?.imageWithTitleView?.highlightedIconImage = accessoryHighlightedIcon
            _accessoryButton?.invalidateLayout()
        }
    }

    /**
     *  Activates/deactivates display of accessory control. By default ```false```.
     */
    public var supportsAccessoryControl: Bool {
        set(newValue) {
            if newValue, _accessoryButton == nil {
                configureAccessoryButton()
                invalidateLayout()
            }

            if !newValue, _accessoryButton != nil {
                _accessoryButton?.removeFromSuperview()
                _accessoryButton = nil

                invalidateLayout()
            }
        }

        get {
            return _accessoryButton != nil
        }
    }

    /// By default `22`
    public var keyRadius: CGFloat = 22.0 {
        didSet {
            applyKeyRadius(keyRadius)
            invalidateLayout()
        }
    }

    // Horizontal spacing between keys. By default `10`
    public var horizontalSpacing: CGFloat = 10.0 {
        didSet {
            invalidateLayout()
        }
    }

    // Vertical spacing between keys. By default `10`
    public var verticalSpacing: CGFloat = 10.0 {
        didSet {
            invalidateLayout()
        }
    }

    public weak var delegate: NumpadViewDelegate?

    private var _buttons: [RoundedButton]?
    private weak var _backspaceButton: RoundedButton?
    private weak var _accessoryButton: RoundedButton?
    private var _accessoryButtonId: String?

    // MARK: Initializers

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    open override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        configure()
    }

    // MARK: Configuration

    /**
     *  Override this method to add additional configuration logic.
     *  It is **not supposed** to be called directly outside of the class.
     */
    open func configure() {
        configureNumButtons()
        configureBackspaceButton()

        applyStyle()
    }

    private func configureNumButtons() {
        if _buttons == nil {
            _buttons = [RoundedButton]()

            for index in 0..<10 {
                let numButton = RoundedButton()
                numButton.imageWithTitleView?.title = String(index)
                numButton.addTarget(self, action: #selector(actionDidSelectNumpad(sender:)), for: .touchUpInside)
                addSubview(numButton)
                _buttons?.append(numButton)
            }
        }
    }

    private func configureBackspaceButton() {
        if _backspaceButton == nil {
            let backspaceButton = RoundedButton()
            backspaceButton.addTarget(self, action: #selector(actionDidSelectBackspace(sender:)), for: .touchUpInside)
            addSubview(backspaceButton)
            _backspaceButton = backspaceButton
        }
    }

    private func configureAccessoryButton() {
        if _accessoryButton == nil {
            let accessoryButton = RoundedButton()
            accessoryButton.imageWithTitleView?.iconImage = accessoryIcon
            accessoryButton.imageWithTitleView?.highlightedIconImage = accessoryHighlightedIcon
            accessoryButton.addTarget(self, action: #selector(actionDidSelectAccessory(sender:)), for: .touchUpInside)
            addSubview(accessoryButton)

            if let fillColor = fillColor {
                accessoryButton.roundedBackgroundView?.fillColor = fillColor
            }

            if let highlightedFillColor = highlightedFillColor {
                accessoryButton.roundedBackgroundView?.highlightedFillColor = highlightedFillColor
            }

            accessoryButton.roundedBackgroundView?.cornerRadius = keyRadius
            accessoryButton.roundedBackgroundView?.shadowOpacity = shadowOpacity
            accessoryButton.roundedBackgroundView?.shadowRadius = shadowRadius
            accessoryButton.roundedBackgroundView?.shadowOffset = shadowOffset

            if let shadowColor = shadowColor {
                accessoryButton.roundedBackgroundView?.shadowColor = shadowColor
            }

            _accessoryButton = accessoryButton
            _accessoryButton?.accessibilityIdentifier = _accessoryButtonId
        }
    }

    // MARK: Layout Management

    /// Prefer to use this method to force layout update instead of `setNeedsLayouts`
    open func invalidateLayout() {
        setNeedsUpdateConstraints()
        setNeedsLayout()
    }

    open override var intrinsicContentSize: CGSize {
        let width = CGFloat(NumpadView.numberOfColums) * 2.0 * keyRadius
            + CGFloat((NumpadView.numberOfColums - 1)) * horizontalSpacing
        let height = CGFloat(NumpadView.numberOfRows) * 2.0 * keyRadius
            + CGFloat((NumpadView.numberOfRows - 1)) * verticalSpacing
        return CGSize(width: width, height: height)
    }

    open override func layoutSubviews() {
        super.layoutSubviews()

        layoutAllRowsExceptLast()
        layoutZeroNumButton()
        layoutBackspaceButton()
        layoutAccessoryButton()
    }

    private func layoutAllRowsExceptLast() {
        if let buttons = _buttons {
            let contentSize = self.intrinsicContentSize
            let originX = self.bounds.midX - contentSize.width / 2.0
            let originY = self.bounds.midY - contentSize.height / 2.0
            let numSize = CGSize(width: 2 * keyRadius, height: 2 * keyRadius)
            var index = 1
            for row in 0..<NumpadView.numberOfRows - 1 {
                for column in 0..<NumpadView.numberOfColums {
                    let xPos = originX + CGFloat(column) * (2.0 * keyRadius + horizontalSpacing)
                    let yPos = originY + CGFloat(row) * (2.0 * keyRadius + verticalSpacing)
                    buttons[index].frame = CGRect(origin: CGPoint(x: xPos, y: yPos), size: numSize)
                    index += 1
                }
            }
        }
    }

    private func layoutZeroNumButton() {
        if let buttons = _buttons {
            let contentSize = self.intrinsicContentSize
            let originX = self.bounds.midX - contentSize.width / 2.0
            let originY = self.bounds.midY - contentSize.height / 2.0

            let keySize = CGSize(width: 2 * keyRadius, height: 2 * keyRadius)
            let xPos = originX + contentSize.width / 2.0 - keySize.width / 2.0
            let yPos = originY + CGFloat(NumpadView.numberOfRows - 1) * (2.0 * keyRadius + verticalSpacing)
            buttons[0].frame = CGRect(origin: CGPoint(x: xPos, y: yPos), size: keySize)
        }
    }

    private func layoutBackspaceButton() {
        if let backspaceButton = _backspaceButton {
            let contentSize = self.intrinsicContentSize
            let originX = self.bounds.midX - contentSize.width / 2.0
            let originY = self.bounds.midY - contentSize.height / 2.0

            let numSize = CGSize(width: 2 * keyRadius, height: 2 * keyRadius)
            let xPos = originX + CGFloat(NumpadView.numberOfColums - 1) * (2.0 * keyRadius + horizontalSpacing)
            let yPos = originY + CGFloat(NumpadView.numberOfRows - 1) * (2.0 * keyRadius + verticalSpacing)
            backspaceButton.frame = CGRect(origin: CGPoint(x: xPos, y: yPos), size: numSize)
        }
    }

    private func layoutAccessoryButton() {
        if let accessoryButton = _accessoryButton {
            let contentSize = self.intrinsicContentSize
            let originX = self.bounds.midX - contentSize.width / 2.0
            let originY = self.bounds.midY - contentSize.height / 2.0

            let numSize = CGSize(width: 2 * keyRadius, height: 2 * keyRadius)
            let xPos = originX
            let yPos = originY + CGFloat(NumpadView.numberOfRows - 1) * (2.0 * keyRadius + verticalSpacing)
            accessoryButton.frame = CGRect(origin: CGPoint(x: xPos, y: yPos), size: numSize)
        }
    }

    // MARK: Style Management

    /// Override this method to provide additional logic for styling. Is **not supposed** to be called directly
    open func applyStyle() {
        applyKeyRadius(keyRadius)
    }

    private func applyKeyRadius(_ keyRadius: CGFloat) {
        enumerateBackgrounds { (backgroundView: RoundedView) -> Void in backgroundView.cornerRadius = keyRadius }
    }

    private func applyNumFillColor(_ color: UIColor) {
        enumerateBackgrounds { (backgroundView: RoundedView) -> Void in backgroundView.fillColor = color }
    }

    private func applyNumHighlightedFillColor(_ color: UIColor) {
        enumerateBackgrounds { (backgroundView: RoundedView) -> Void in backgroundView.highlightedFillColor = color }
    }

    private func applyNumTitleColor(_ color: UIColor) {
        enumerateNumTitles { (titleView: ImageWithTitleView) -> Void in titleView.titleColor = color }
    }

    private func applyNumHighlightedTitleColor(_ color: UIColor) {
        enumerateNumTitles { (titleView: ImageWithTitleView) -> Void in titleView.highlightedTitleColor = color }
    }

    private func applyNumFont(_ font: UIFont) {
        enumerateNumTitles { (titleView: ImageWithTitleView) -> Void in titleView.titleFont = font }
    }

    private func applyShadowOpacity(_ opacity: Float) {
        enumerateBackgrounds { (backgroundView: RoundedView) -> Void in backgroundView.shadowOpacity = opacity }
    }

    private func applyShadowColor(_ color: UIColor) {
        enumerateBackgrounds { (backgroundView: RoundedView) -> Void in backgroundView.shadowColor = color }
    }

    private func applyShadowRadius(_ radius: CGFloat) {
        enumerateBackgrounds { (backgroundView: RoundedView) -> Void in backgroundView.shadowRadius = radius }
    }

    private func applyShadowOffset(_ offset: CGSize) {
        enumerateBackgrounds { (backgroundView: RoundedView) -> Void in backgroundView.shadowOffset = offset }
    }

    // MARK: Actions

    @objc private func actionDidSelectNumpad(sender: AnyObject) {
        guard let buttons = _buttons else { return }
        guard let numButton = sender as? RoundedButton else { return }

        if let index = buttons.firstIndex(of: numButton) {
           delegate?.numpadView(self, didSelectNumAt: index)
        }
    }

    @objc private func actionDidSelectBackspace(sender: AnyObject) {
        delegate?.numpadViewDidSelectBackspace(self)
    }

    @objc private func actionDidSelectAccessory(sender: AnyObject) {
        delegate?.numpadViewDidSelectAccessoryControl(self)
    }

    // MARK: Enumeration

    private func enumerateNumButtons(with block: (RoundedButton) -> Void) {
        guard let buttons = _buttons else { return }

        for numButton in buttons {
            block(numButton)
        }
    }

    private func enumerateBackgrounds(with block: (RoundedView) -> Void) {
        if let buttons = _buttons {
            for numButton in buttons {
                if let roundedView = numButton.roundedBackgroundView {
                    block(roundedView)
                }
            }
        }

        if let roundedView = _backspaceButton?.roundedBackgroundView {
            block(roundedView)
        }

        if let roundedView = _accessoryButton?.roundedBackgroundView {
            block(roundedView)
        }
    }

    private func enumerateNumTitles(with block: (ImageWithTitleView) -> Void) {
        guard let buttons = _buttons else { return }

        for numButton in buttons {
            if let titleView = numButton.imageWithTitleView {
                block(titleView)
            }
        }
    }

    private func anyNumBackgroundView() -> RoundedView? {
        guard let buttons = _buttons else { return nil }

        for numButton in buttons {
            if let roundedView = numButton.roundedBackgroundView {
                return roundedView
            }
        }

        return nil
    }

    private func anyNumTitleView() -> ImageWithTitleView? {
        guard let buttons = _buttons else { return nil }

        for numButton in buttons {
            if let titleView = numButton.imageWithTitleView {
                return titleView
            }
        }

        return nil
    }
}

extension NumpadView: NumpadAccessibilitySupportProtocol {
    public func setupKeysAccessibilityIdWith(format: String?) {
        guard let buttons = _buttons else {
            return
        }

        for (index, key) in buttons.enumerated() {
            if let existingFormat = format {
                key.accessibilityIdentifier = existingFormat + "\(index)"
                key.accessibilityTraits = UIAccessibilityTraits.button
            } else {
                key.accessibilityIdentifier = nil
                key.accessibilityTraits = UIAccessibilityTraits.none
            }
        }
    }

    public func setupBackspace(accessibilityId: String?) {
        _backspaceButton?.accessibilityIdentifier = accessibilityId
    }

    public func setupAccessory(accessibilityId: String?) {
        _accessoryButtonId = accessibilityId
        _accessoryButton?.accessibilityIdentifier = accessibilityId
    }
}
