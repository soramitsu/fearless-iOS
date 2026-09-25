import UIKit
import SoraUI

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
        let field = AnimatedTextField()
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
            animatedInputField.title
        }
        set {
            animatedInputField.title = newValue
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
            make.height.equalTo(52.0)
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
