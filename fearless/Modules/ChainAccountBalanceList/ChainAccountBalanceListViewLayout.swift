import UIKit

final class ChainAccountBalanceListViewLayout: UIView {
    let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.image = R.image.backgroundImage()
        return imageView
    }()

    let accountNameLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = .white
        return label
    }()

    let totalBalanceLabel: UILabel = {
        let label = UILabel()
        label.font = .h1Title
        label.textColor = .white
        return label
    }()

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.refreshControl = UIRefreshControl()
        view.separatorStyle = .none
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.bigOffset, right: 0)

        return view
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
        addSubview(backgroundImageView)
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(accountNameLabel)
        accountNameLabel.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        addSubview(totalBalanceLabel)
        totalBalanceLabel.snp.makeConstraints { make in
            make.leading.equalTo(accountNameLabel.snp.leading)
            make.top.equalTo(accountNameLabel.snp.bottom).offset(UIConstants.defaultOffset)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(totalBalanceLabel.snp.bottom).offset(UIConstants.bigOffset)
            make.bottom.equalToSuperview()
        }
    }

    func bind(to viewModel: ChainAccountBalanceListViewModel) {
        accountNameLabel.text = viewModel.accountName
        totalBalanceLabel.text = viewModel.balance
    }
}
