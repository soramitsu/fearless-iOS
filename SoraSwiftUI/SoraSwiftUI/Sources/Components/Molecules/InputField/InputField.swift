import UIKit

public final class InputField: UIView, Molecule {

    public let sora: InputFieldConfiguration<InputField>

    let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
    }()

    let leftImageView: UIImageView = {
        let view = UIImageView()
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 24).isActive = true
        view.widthAnchor.constraint(equalToConstant: 24).isActive = true
        return view
    }()

    let infoStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
    }()

    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.textXS
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }()

    public lazy var textField: SoramitsuTextField = {
        let textField = SoramitsuTextField()
        textField.sora.placeholderColor = .fgSecondary
        textField.setContentCompressionResistancePriority(.required, for: .vertical)
        textField.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.titleLabel.sora.isHidden = !(textField.text?.isEmpty ?? true)
        }
        textField.sora.addHandler(for: .editingDidBegin) { [weak self] in
            self?.sora.state = .focused
        }
        textField.sora.addHandler(for: .editingDidEnd) { [weak self] in
            self?.sora.state = .default
        }
        return textField
    }()

    public let button: ImageButton = {
        let view = ImageButton(size: CGSize(width: 24, height: 24))
        view.isHidden = true
        return view
    }()

    public let descriptionLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.isHidden = true
        label.sora.numberOfLines = 0
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.textXS
        return label
    }()

    init(style: SoramitsuStyle) {
        sora = InputFieldConfiguration(style: style, state: .default)
        super.init(frame: .zero)
        sora.owner = self
        setup()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @available(*, unavailable)
    public override init(frame: CGRect) { fatalError("init(coder:) has not been implemented") }
}

private extension InputField {
    func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        stackView.layer.cornerRadius = 28
        stackView.layer.borderWidth = 1

        addSubview(stackView)
        stackView.addArrangedSubviews([leftImageView, infoStackView, button])
        infoStackView.addArrangedSubviews([titleLabel, textField])
        addSubview(descriptionLabel)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 56),

            descriptionLabel.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 16),
            descriptionLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}


public extension InputField {

    convenience init() {
        let sora = SoramitsuUI.shared
        self.init(style: sora.style)
    }
}
