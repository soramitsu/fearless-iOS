import UIKit
import SnapKit

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

    let activityIndicatorView: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .white)
        activityIndicator.hidesWhenStopped = true
        return activityIndicator
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let bottomInset = abs(distanceBetween(bottomOf: self, andTopOf: payoutButton))
            + UIConstants.horizontalInset
        tableView.contentInset = .init(top: 0, left: 0, bottom: bottomInset, right: 0)
    }

    private func distanceBetween(bottomOf view1: UIView, andTopOf view2: UIView) -> CGFloat {
        let frame2 = view1.convert(view2.bounds, from: view2)
        return frame2.minY - view1.bounds.maxY
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
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.horizontalInset)
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

        addSubview(activityIndicatorView)
        activityIndicatorView.snp.makeConstraints { $0.center.equalToSuperview() }
    }
}
