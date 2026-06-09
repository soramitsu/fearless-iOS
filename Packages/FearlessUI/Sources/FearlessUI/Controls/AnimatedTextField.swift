import UIKit

public protocol AnimatedTextFieldDelegate: AnyObject {
    func animatedTextFieldShouldReturn(_ textField: AnimatedTextField) -> Bool
    func animatedTextField(_ textField: AnimatedTextField,
                           shouldChangeCharactersIn range: NSRange,
                           replacementString string: String) -> Bool
}

extension AnimatedTextFieldDelegate {
    func animatedTextFieldShouldReturn(_ textField: AnimatedTextField) -> Bool { true }

    func animatedTextField(_ textField: AnimatedTextField,
                           shouldChangeCharactersIn range: NSRange,
                           replacementString string: String) -> Bool {
        return true
    }
}

@IBDesignable
open class AnimatedTextField: UIControl {
    enum DisplayMode {
        case placeholder
        case title
    }

    private var titleLabel: UILabel!

    public private(set) var textField: UITextField!

    private var displayMode: DisplayMode = .placeholder

    private var animating: Bool = false

    @IBInspectable
    open var placeholderColor: UIColor = UIColor.lightGray {
        didSet {
            if displayMode == .placeholder {
                titleLabel.textColor = placeholderColor
            }
        }
    }

    open var placeholderFont: UIFont = UIFont.systemFont(ofSize: 14.0) {
        didSet {
            if displayMode == .placeholder {
                titleLabel.font = placeholderFont
            }
        }
    }

    @IBInspectable
    open var titleColor: UIColor = UIColor.lightGray {
        didSet {
            if displayMode == .title {
                titleLabel.textColor = titleColor
            }
        }
    }

    open var titleFont: UIFont = UIFont.systemFont(ofSize: 12.0) {
        didSet {
            if displayMode == .title {
                titleLabel.font = titleFont
            }
        }
    }

    @IBInspectable
    open var textColor: UIColor? {
        get {
            textField.textColor
        }

        set {
            textField.textColor = newValue
        }
    }

    @IBInspectable
    open var textFont: UIFont? {
        get {
            textField.font
        }

        set {
            textField.font = newValue
        }
    }

    @IBInspectable
    open var cursorColor: UIColor {
        get {
            textField.tintColor
        }

        set {
            textField.tintColor = newValue
        }
    }

    open weak var delegate: AnimatedTextFieldDelegate?

    open var contentInsets: UIEdgeInsets = UIEdgeInsets(top: 4.0, left: 4.0, bottom: 4.0, right: 4.0) {
        didSet {
            setNeedsLayout()
        }
    }

    @IBInspectable
    open var title: String? {
        get {
            titleLabel.text
        }

        set {
            titleLabel.text = newValue
        }
    }

    @IBInspectable
    open var text: String? {
        get {
            textField.text
        }

        set {
            if let newValue = newValue, !newValue.isEmpty {
                set(mode: .title, animated: false)
            } else if !textField.isFirstResponder {
                set(mode: .placeholder, animated: false)
            }

            textField.text = newValue
        }
    }

    open var animator: BlockViewAnimatorProtocol = BlockViewAnimator(duration: 0.1,
                                                                     delay: 0.0,
                                                                     options: .curveLinear)

    public override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)

        configure()
    }

    @discardableResult
    public override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()

        set(mode: .title, animated: true)

        return textField.becomeFirstResponder()
    }

    @discardableResult
    public override func resignFirstResponder() -> Bool {
        super.resignFirstResponder()

        if let text = text, text.isEmpty {
            set(mode: .placeholder, animated: true)
        }

        return textField.resignFirstResponder()
    }

    private func configure() {
        if titleLabel == nil {
            titleLabel = UILabel()
            addSubview(titleLabel)

            titleLabel.textColor = placeholderColor
            titleLabel.font = placeholderFont
        }

        if textField == nil {
            textField = UITextField()
            textField.delegate = self
            textField.borderStyle = .none
            addSubview(textField)

            textField.textColor = textColor
            textField.font = textFont

            addTarget(self, action: #selector(actionTouchUpInside), for: .touchUpInside)

            textField.addTarget(self, action: #selector(actionEditingChanged), for: .editingChanged)
        }
    }

    open override func layoutSubviews() {
        super.layoutSubviews()

        layoutForMode(displayMode)
    }

    private func layoutForMode(_ mode: DisplayMode) {
        guard !animating else {
            return
        }

        switch mode {
        case .placeholder:
            layoutForPlaceholderMode()
        case .title:
            layoutForTitleMode()
        }
    }

    private func layoutForPlaceholderMode() {
        let titleSize = titleLabel.intrinsicContentSize

        titleLabel.frame = CGRect(x: contentInsets.left,
                                  y: bounds.midY - titleSize.height / 2.0,
                                  width: bounds.width - contentInsets.left - contentInsets.right,
                                  height: titleSize.height)

        let fieldSize = textField.intrinsicContentSize

        textField.frame = CGRect(x: contentInsets.left,
                                 y: bounds.height - contentInsets.bottom - fieldSize.height,
                                 width: bounds.width - contentInsets.left - contentInsets.right,
                                 height: fieldSize.height)
    }

    private func layoutForTitleMode() {
        let titleSize = titleLabel.intrinsicContentSize

        titleLabel.frame = CGRect(x: contentInsets.left,
                                  y: contentInsets.top,
                                  width: bounds.width - contentInsets.left - contentInsets.right,
                                  height: titleSize.height)

        let fieldSize = textField.intrinsicContentSize

        textField.frame = CGRect(x: contentInsets.left,
                                 y: bounds.height - contentInsets.bottom - fieldSize.height,
                                 width: bounds.width - contentInsets.left - contentInsets.right,
                                 height: fieldSize.height)
    }

    private func setupStyleForMode(_ mode: DisplayMode) {
        switch mode {
        case .placeholder:
            titleLabel.textColor = placeholderColor
            titleLabel.font = placeholderFont

            textField.isHidden = true
        case .title:
            titleLabel.textColor = titleColor
            titleLabel.font = titleFont

            textField.isHidden = false
        }
    }

    private func set(mode: DisplayMode, animated: Bool) {
        guard displayMode != mode else {
            return
        }

        displayMode = mode

        guard animated else {
            setupStyleForMode(mode)
            layoutForMode(mode)

            return
        }

        let scale: CGFloat
        let color: UIColor
        let center: CGPoint

        switch mode {
        case .title:
            scale = titleFont.pointSize / placeholderFont.pointSize
            color = titleColor

            center = CGPoint(x: contentInsets.left + titleLabel.bounds.width * scale / 2.0,
                             y: contentInsets.top + titleLabel.bounds.height * scale / 2.0)

        case .placeholder:
            scale = placeholderFont.pointSize / titleFont.pointSize
            color = placeholderColor

            center = CGPoint(x: contentInsets.left + titleLabel.bounds.width * scale / 2.0,
                             y: bounds.midY)
        }

        let offsetX = center.x - titleLabel.center.x
        let offsetY = center.y - titleLabel.center.y

        animating = true

        let changeClosure: () -> Void = { [weak self] in
            self?.titleLabel.textColor = color
            self?.titleLabel.transform = CGAffineTransform(translationX: offsetX, y: offsetY)
                .scaledBy(x: scale, y: scale)
        }

        animator.animate(block: changeClosure) { [weak self] _ in
            self?.animating = false

            self?.titleLabel.transform = .identity
            self?.setupStyleForMode(mode)
            self?.layoutForMode(mode)
        }
    }

    @objc func actionTouchUpInside() {
        guard !textField.isFirstResponder else {
            return
        }

        textField.becomeFirstResponder()

        set(mode: .title, animated: true)
    }

    @objc func actionEditingChanged() {
        sendActions(for: .editingChanged)
    }
}

extension AnimatedTextField: UITextFieldDelegate {

    public func textFieldDidBeginEditing(_ textField: UITextField) {
        set(mode: .title, animated: true)
    }

    public func textFieldDidEndEditing(_ textField: UITextField) {
        if let text = text, text.isEmpty {
            set(mode: .placeholder, animated: true)
        }
    }

    public func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        delegate?.animatedTextField(self,
                                    shouldChangeCharactersIn: range,
                                    replacementString: string)
        ?? true
    }

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        delegate?.animatedTextFieldShouldReturn(self) ?? true
    }
}
