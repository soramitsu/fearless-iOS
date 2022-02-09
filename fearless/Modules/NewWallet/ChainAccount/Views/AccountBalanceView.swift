import UIKit

class AccountBalanceView: TriangularedBlurView {
    let balanceViewTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = .white
        return label
    }()

    let balanceContentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()

    let totalView = TitleMultiValueView()
    let transferableView = TitleMultiValueView()
    let lockedView = LockedBalanceMultiValueView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(balanceViewTitleLabel)
        balanceViewTitleLabel.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(UIConstants.bigOffset)
        }
        addSubview(balanceContentStackView)
        balanceContentStackView.snp.makeConstraints { make in
            make.width.equalToSuperview().inset(UIConstants.bigOffset)
            make.centerX.equalToSuperview()
            make.top.equalTo(balanceViewTitleLabel.snp.bottom).offset(UIConstants.bigOffset)
            make.bottom.equalToSuperview()
        }

        balanceContentStackView.addArrangedSubview(totalView)
        balanceContentStackView.addArrangedSubview(transferableView)
        balanceContentStackView.addArrangedSubview(lockedView)
    }

    func bind(to viewModel: AccountBalanceViewModel) {
        totalView.valueTop.text = viewModel.totalAmountString
        totalView.valueBottom.text = viewModel.totalAmountFiatString
        transferableView.valueTop.text = viewModel.transferableAmountString
        transferableView.valueBottom.text = viewModel.transferableAmountFiatString
        lockedView.valueTop.text = viewModel.lockedAmountString
        lockedView.valueBottom.text = viewModel.lockedAmountFiatString
        lockedView.button.isEnabled = !viewModel.isEmptyAccount
    }
}
