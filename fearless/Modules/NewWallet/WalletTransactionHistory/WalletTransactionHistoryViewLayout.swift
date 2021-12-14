import UIKit
import SoraUI

final class WalletTransactionHistoryViewLayout: UIView {
    enum Constants {
        static let buttonSize: CGFloat = 40
    }

    let backgroundView = TriangularedBlurView()

    let tableView: UITableView = {
        UITableView()
    }()

    let contentView = UIView()

    let closeButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconClose(), for: .normal)
        return button
    }()

    let filterButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(R.image.iconFilter(), for: .normal)
        return button
    }()

    let headerView = UIView()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p0Paragraph
        return label
    }()

    let panIndicatorView = RoundedView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        addSubview(backgroundView)
        addSubview(headerView)
        addSubview(contentView)
        addSubview(tableView)

        headerView.addSubview(closeButton)
        headerView.addSubview(titleLabel)
        headerView.addSubview(filterButton)

        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        headerView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
            make.top.equalTo(headerView.snp.bottom)
        }

        tableView.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
            make.top.equalTo(headerView.snp.bottom)
        }

        closeButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.buttonSize)
            make.bottom.top.greaterThanOrEqualToSuperview()
        }

        filterButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.buttonSize)
            make.bottom.top.greaterThanOrEqualToSuperview()
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(closeButton.snp.trailing).offset(UIConstants.bigOffset)
            make.trailing.equalTo(filterButton.snp.leading).inset(UIConstants.bigOffset)
            make.top.bottom.equalToSuperview()
        }
    }

    func setHeaderHeight(_ height: CGFloat) {
        headerView.snp.remakeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.height.equalTo(height)
        }
    }

    func setHeaderTopOffset(_ offset: CGFloat) {
        headerView.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(offset)
        }
    }
}
