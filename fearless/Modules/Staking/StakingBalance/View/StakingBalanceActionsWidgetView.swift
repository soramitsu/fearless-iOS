import UIKit

protocol StakingBalanceActionsWidgetViewDelegate: AnyObject {
    func didSelect(action: StakingBalanceAction)
}

final class StakingBalanceActionsWidgetView: UIView {
    weak var delegate: StakingBalanceActionsWidgetViewDelegate?

    private let backgroundView: UIView = TriangularedBlurView()

    private let bondMoreButton = StakingBalanceActionButton(action: .bondMore)
    private let unbondButton = StakingBalanceActionButton(action: .unbond)
    private let redeemButton = StakingBalanceActionButton(action: .redeem)

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()

        [bondMoreButton, unbondButton, redeemButton].forEach { button in
            button.addTarget(self, action: #selector(handleActionButton(sender:)), for: .touchUpInside)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let stackView = UIStackView(arrangedSubviews: [bondMoreButton, unbondButton, redeemButton])
        stackView.distribution = .equalSpacing

        backgroundView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(8)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }
    }

    @objc
    func handleActionButton(sender: UIButton) {
        guard let actionButton = sender as? StakingBalanceActionButton else { return }
        delegate?.didSelect(action: actionButton.action)
    }
}

private final class StakingBalanceActionButton: UIButton {
    let action: StakingBalanceAction

    let iconImageView = UIImageView()

    let actionTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    init(action: StakingBalanceAction) {
        self.action = action
        super.init(frame: .zero)
        setupLayout()

        iconImageView.image = action.iconImage
        iconImageView.isUserInteractionEnabled = false

        actionTitleLabel.text = action.title(for: .current)
        actionTitleLabel.isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.size.equalTo(24)
        }

        addSubview(actionTitleLabel)
        actionTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(8)
            make.bottom.leading.trailing.equalToSuperview()
        }
    }
}
