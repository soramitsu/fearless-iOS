import UIKit

class HorizontalKeyValueView: UIView {
    struct Style {
        var keyLabelFont: UIFont = .h3Title
        var valueLabelFont: UIFont = .h3Title
        var keyLabelTextColor: UIColor? = R.color.colorWhite()
        var valueLabelTextColor: UIColor? = R.color.colorWhite()
    }

    private var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        return stackView
    }()

    let keyLabel: ShimmeredLabel = {
        let label = ShimmeredLabel()
        label.textColor = R.color.colorWhite()
        label.font = .h3Title
        return label
    }()

    let valueLabel: ShimmeredLabel = {
        let label = ShimmeredLabel()
        label.textColor = R.color.colorWhite()
        label.font = .h3Title
        label.textAlignment = .right
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        stackView.addArrangedSubview(keyLabel)
        stackView.addArrangedSubview(valueLabel)

        keyLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        valueLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    }

    func apply(style: HorizontalKeyValueView.Style) {
        keyLabel.font = style.keyLabelFont
        keyLabel.textColor = style.keyLabelTextColor
        valueLabel.font = style.valueLabelFont
        valueLabel.textColor = style.valueLabelTextColor
    }
}
