import UIKit
import SoraUI
import SnapKit

class CommonInputView: UIView {
    let backgroundView: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = .clear
        view.highlightedFillColor = .clear
        view.strokeColor = R.color.colorDarkGray()!
        view.highlightedStrokeColor = R.color.colorDarkGray()!
        view.strokeWidth = 1.0
        return view
    }()

    let animatedInputField: AnimatedTextField = {
        let field = WalletEntryAnimatedTextField()
        field.placeholderFont = .p1Paragraph
        field.placeholderColor = R.color.colorGray()!
        field.textColor = R.color.colorWhite()!
        field.textFont = .p1Paragraph
        field.cursorColor = R.color.colorWhite()!
        if #available(iOS 17.0, *) {
            field.textField.accessibilityFrameBlock = { [weak field] in
                guard let field else { return .zero }
                return UIAccessibility.convertToScreenCoordinates(field.bounds, in: field)
            }
        }
        return field
    }()

    let rightButton: UIButton = {
        let button = UIButton()
        button.isHidden = true
        return button
    }()

    let captionLabel = UILabel()
    private var adaptiveCaption = false
    private var fixedHeight: Constraint?

    /// Opt in only on qualified entry forms; keep the existing editor and delegate.
    func configureAdaptiveCaption(locale: Locale, compatibleWith traits: UITraitCollection) {
        if !adaptiveCaption {
            let existingTitle = animatedInputField.title
            adaptiveCaption = true
            (animatedInputField as? WalletEntryAnimatedTextField)?.usesExternalCaption = true
            animatedInputField.title = nil
            captionLabel.text = existingTitle
            captionLabel.numberOfLines = 0
            captionLabel.isAccessibilityElement = false
            captionLabel.textColor = animatedInputField.placeholderColor
            addSubview(captionLabel)
            fixedHeight?.deactivate()
            rightButton.snp.remakeConstraints { make in
                make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
                make.width.equalTo(52)
            }
            captionLabel.snp.makeConstraints { make in
                make.top.leading.trailing.equalToSuperview().inset(16)
            }
            inputContainer.snp.remakeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(captionLabel.snp.bottom).offset(8)
                make.bottom.equalToSuperview().inset(16)
                make.height.greaterThanOrEqualTo(44)
            }
        }
        captionLabel.font = .fw(.bodyS, locale: locale, compatibleWith: traits)
        animatedInputField.textFont = .fw(.bodyL, locale: locale, compatibleWith: traits)
        animatedInputField.contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 16)
        // UITextField remains a single-line, horizontally scrolling secure-capable editor.
        inputContainer.snp.updateConstraints { make in
            make.height.greaterThanOrEqualTo(max(44, ceil(animatedInputField.textFont?.lineHeight ?? 0)))
        }
        setNeedsLayout()
    }

    private let inputContainer = UIFactory.default.createHorizontalStackView()

    var text: String? {
        get {
            animatedInputField.text
        }
        set {
            animatedInputField.text = newValue
        }
    }

    var title: String? {
        get {
            adaptiveCaption ? captionLabel.text : animatedInputField.title
        }
        set {
            if adaptiveCaption { captionLabel.text = newValue } else { animatedInputField.title = newValue }
            animatedInputField.textField.accessibilityLabel = newValue
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        inputContainer.layoutIfNeeded()
        // AnimatedTextField forwards taps across its full bounds to this input.
        // Keep the stored frame coherent for direct accessibility consumers too.
        // On iOS 17+, the dynamic block still takes precedence for VoiceOver.
        animatedInputField.textField.accessibilityFrame = UIAccessibility.convertToScreenCoordinates(
            animatedInputField.bounds, in: animatedInputField
        )
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            fixedHeight = make.height.equalTo(52.0).constraint
        }

        addSubview(inputContainer)
        inputContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(4.0)
        }
        inputContainer.addArrangedSubview(animatedInputField)
        animatedInputField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
        }
        inputContainer.addArrangedSubview(rightButton)
        rightButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.size.equalTo(52)
        }
    }
}

extension CommonInputView {
    func defaultSetup() {
        animatedInputField.textField.returnKeyType = .done
        animatedInputField.textField.textContentType = .nickname
        animatedInputField.textField.autocapitalizationType = .none
        animatedInputField.textField.autocorrectionType = .no
        animatedInputField.textField.spellCheckingType = .no
    }

    func disable() {
        backgroundView.applyDisabledStyle()
        isUserInteractionEnabled = false
    }

    func enable() {
        backgroundView.applyEnabledStyle()
        isUserInteractionEnabled = true
    }
}

/// SoraUI hides its empty editor in placeholder mode. An external wrapping caption
/// needs the same native text field to remain reachable even when its value is empty.
private final class WalletEntryAnimatedTextField: AnimatedTextField {
    var usesExternalCaption = false

    override func layoutSubviews() {
        super.layoutSubviews()
        guard usesExternalCaption else { return }
        textField.isHidden = false
        textField.frame = bounds.inset(by: contentInsets)
    }
}
