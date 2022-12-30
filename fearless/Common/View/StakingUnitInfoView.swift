import UIKit

struct StakingUnitInfoViewModel {
    let value: String?
    let subtitle: String?
}

final class StakingUnitInfoView: UIView {
    private let stackView: UIStackView = {
        let stackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.minimalOffset)
        stackView.distribution = .fill
        return stackView
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorGray()
        return label
    }()

    let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .p0Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorGray()
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

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(valueLabel)
        stackView.addArrangedSubview(subtitleLabel)
    }

    func bind(title: String?) {
        titleLabel.text = title
    }

    func bind(value: String?) {
        valueLabel.text = value
    }

    func bind(subtitle: String?) {
        subtitleLabel.text = subtitle
    }
}
