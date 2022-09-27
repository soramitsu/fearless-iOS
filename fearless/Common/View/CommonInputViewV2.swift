import UIKit
import SoraUI

class CommonInputViewV2: UIView {
    let backgroundView: TriangularedView = {
        let view = TriangularedView()
        view.isUserInteractionEnabled = true

        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!

        view.strokeColor = R.color.colorWhite8()!
        view.highlightedStrokeColor = R.color.colorWhite8()!
        view.strokeWidth = 0.5
        view.layer.shadowOpacity = 0

        return view
    }()

    let animatedInputField: AnimatedTextField = {
        let field = AnimatedTextField()
        field.placeholderFont = .h5Title
        field.placeholderColor = R.color.colorStrokeGray()!
        field.textColor = R.color.colorWhite()!
        field.textFont = .p1Paragraph
        field.cursorColor = R.color.colorWhite()!
        return field
    }()

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

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(52.0)
        }

        addSubview(animatedInputField)
        animatedInputField.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.bottom.equalToSuperview().inset(4.0)
        }
    }
}

extension CommonInputViewV2 {
    func defaultSetup() {
        animatedInputField.textField.returnKeyType = .done
        animatedInputField.textField.textContentType = .nickname
        animatedInputField.textField.autocapitalizationType = .none
        animatedInputField.textField.autocorrectionType = .no
        animatedInputField.textField.spellCheckingType = .no
    }

    func disable() {
        backgroundView.fillColor = R.color.colorAlmostBlack()!
        backgroundView.strokeColor = .clear
        isUserInteractionEnabled = false
    }

    func enable() {
        backgroundView.applyEnabledStyle()
        isUserInteractionEnabled = true
    }
}
