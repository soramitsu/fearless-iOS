import UIKit

final class AlertsView: UIView {
    private let backgroundView: UIView = TriangularedBlurView()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    let noAlertsLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorWhite()?.withAlphaComponent(0.64)
        return label
    }()

    private let alertsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        applyLocalization()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocalization() {
        titleLabel.text = "Alerts"
        noAlertsLabel.text = "Everything is fine now. Alerts will appear here."
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        let separatorView = UIView.createSeparator(color: R.color.colorWhite()?.withAlphaComponent(0.24))
        addSubview(separatorView)
        separatorView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(15)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(0.75)
        }

        addSubview(noAlertsLabel)
        noAlertsLabel.snp.makeConstraints { make in
            make.top.equalTo(separatorView.snp.bottom).offset(UIConstants.horizontalInset)
            make.leading.trailing.bottom.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(alertsStackView)
        alertsStackView.snp.makeConstraints { make in
            make.top.equalTo(separatorView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().inset(8)
        }
    }

    func bind(viewModels: [StakingAlertViewModel]) {
        if viewModels.isEmpty {
            noAlertsLabel.isHidden = false
            alertsStackView.isHidden = true
        } else {
            noAlertsLabel.isHidden = true
            alertsStackView.isHidden = false

            let itemViews = viewModels.map { viewModel -> UIView in
                let itemView = AlertItemView()
                itemView.bind(viewModel: viewModel)
                return itemView
            }

            alertsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            itemViews.forEach { alertsStackView.addArrangedSubview($0) }
        }
    }
}

private class AlertItemView: UIView {
    func bind(viewModel _: StakingAlertViewModel) {}
}
