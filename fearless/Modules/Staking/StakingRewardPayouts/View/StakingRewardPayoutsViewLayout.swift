import UIKit

final class StakingRewardPayoutsViewLayout: UIView {
    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = R.color.colorBlack()
        tableView.separatorStyle = .none
        return tableView
    }()

    let payoutButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    let emptyImageView: UIView = UIImageView(image: R.image.iconEmptyHistory())
    let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "Your rewards\nwill appear here"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = R.color.colorGray()
        label.font = .p2Paragraph
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
        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.bottom.trailing.equalToSuperview()
        }

        addSubview(payoutButton)
        payoutButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(emptyLabel)
        emptyLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        addSubview(emptyImageView)
        emptyImageView.snp.makeConstraints { make in
            make.bottom.equalTo(emptyLabel.snp.top)
            make.centerX.equalToSuperview()
        }
    }
}
