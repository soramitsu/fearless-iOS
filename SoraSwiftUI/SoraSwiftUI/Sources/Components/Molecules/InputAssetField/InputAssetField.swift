import UIKit

public final class InputAssetField: UIControl, Molecule {

    public let sora: InputAssetFieldConfiguration<InputAssetField>

    let containerView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.cornerRadius = .max
        view.sora.backgroundColor = .bgSurface
        view.sora.borderWidth = 1
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let assetImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.tintColor = .fgSecondary
        return view
    }()

    public let choiceButton: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.backgroundColor = .custom(uiColor: .clear)
        button.sora.horizontalOffset = 0
        button.sora.imageSize = 16
        button.sora.tintColor = .fgSecondary
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let fullFiatAmountLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.textBoldXS
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()
    
    public lazy var textField: SoramitsuTextField = {
        let textField = SoramitsuTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.sora.textColor = .fgPrimary
        textField.sora.font = FontType.displayS
        textField.textAlignment = .right
        
        textField.sora.addHandler(for: .editingChanged) {
            self.sora.text = textField.text
        }
        textField.sora.addHandler(for: .editingDidBegin) { [weak self] in
            self?.sora.state = .focused
        }
        textField.sora.addHandler(for: .editingDidEnd) { [weak self] in
            self?.sora.state = .default
        }
        return textField
    }()

    public let inputedFiatAmountLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.textBoldXS
        label.sora.alignment = .right
        return label
    }()

    init(style: SoramitsuStyle) {
        sora = InputAssetFieldConfiguration(style: style, state: .default)
        super.init(frame: .zero)
        sora.owner = self
        setup()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @available(*, unavailable)
    public override init(frame: CGRect) { fatalError("init(coder:) has not been implemented") }
}

private extension InputAssetField {
    func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        
        sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.textField.becomeFirstResponder()
        }

        addSubview(containerView)
        containerView.addSubview(assetImageView)
        containerView.addSubview(choiceButton)
        containerView.addSubview(fullFiatAmountLabel)
        containerView.addSubview(textField)
        containerView.addSubview(inputedFiatAmountLabel)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            assetImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            assetImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            assetImageView.heightAnchor.constraint(equalToConstant: 40),
            assetImageView.widthAnchor.constraint(equalToConstant: 40),
            assetImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

            choiceButton.leadingAnchor.constraint(equalTo: assetImageView.trailingAnchor, constant: 8),
            choiceButton.topAnchor.constraint(equalTo: assetImageView.topAnchor),
            choiceButton.heightAnchor.constraint(equalToConstant: 24),
            
            fullFiatAmountLabel.leadingAnchor.constraint(equalTo: assetImageView.trailingAnchor, constant: 8),
            fullFiatAmountLabel.bottomAnchor.constraint(equalTo: assetImageView.bottomAnchor),
            
            textField.leadingAnchor.constraint(equalTo: choiceButton.trailingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            textField.topAnchor.constraint(equalTo: assetImageView.topAnchor),
            
            inputedFiatAmountLabel.leadingAnchor.constraint(equalTo: fullFiatAmountLabel.trailingAnchor, constant: 8),
            inputedFiatAmountLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            inputedFiatAmountLabel.bottomAnchor.constraint(equalTo: assetImageView.bottomAnchor),
        ])
    }
}


public extension InputAssetField {

    convenience init() {
        let sora = SoramitsuUI.shared
        self.init(style: sora.style)
    }
}
