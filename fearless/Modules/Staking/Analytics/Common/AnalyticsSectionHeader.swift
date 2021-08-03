import UIKit

final class AnalyticsSectionHeader: UITableViewHeaderFooterView {
    let label: UILabel = {
        let label = UILabel()
        label.font = .capsTitle
        label.textColor = R.color.colorGray()
        return label
    }()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        backgroundView = UIView()
        backgroundView?.backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(6)
            make.bottom.equalToSuperview().inset(5)
        }
    }
}
