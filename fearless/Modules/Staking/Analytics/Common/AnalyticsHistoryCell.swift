import UIKit

final class AnalyticsHistoryCell: UITableViewCell {
    let historyView = AnalyticsRewardsItemView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.addSubview(historyView)
        historyView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
}
