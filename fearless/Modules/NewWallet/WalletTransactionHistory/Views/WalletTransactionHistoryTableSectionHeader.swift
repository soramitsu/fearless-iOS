import UIKit

class WalletTransactionHistoryTableSectionHeader: UIView {
    let label: UILabel = {
        let label = UILabel()
        label.font = .capsTitle
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
        addSubview(label)

        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.top.equalToSuperview().offset(UIConstants.minimalOffset)
            make.bottom.equalToSuperview().inset(UIConstants.minimalOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }
    }

    func bind(to viewModel: WalletTransactionHistorySection) {
        label.text = viewModel.title.uppercased()
    }
}
