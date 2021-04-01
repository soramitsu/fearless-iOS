import UIKit

final class StakingRewardHistoryHeaderView: UITableViewHeaderFooterView {

    private let eraLabel: UILabel = {
        let label = UILabel()
        label.font = .capsTitle
        label.textColor = R.color.colorWhite()
        return label
    }()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        tintColor = R.color.colorBlack()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.addSubview(eraLabel)
        eraLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            eraLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            eraLabel.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: UIConstants.horizontalInset),
            eraLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            eraLabel.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -UIConstants.horizontalInset)
        ])
    }
}

extension StakingRewardHistoryHeaderView {

    typealias Model = String

    func bind(model: Model) {
        eraLabel.text = model
    }
}
