import UIKit
import SoraUI

final class WalletTransactionHistoryViewLayout: UIView {
    enum Constants {
        static let buttonSize: CGFloat = 40
        static let stripeSize = CGSize(width: 35, height: 2)
        static let stripeTopOffset: CGFloat = 2
    }

    let containerView = UIView()
    let backgroundView = TriangularedBlurView()

    let stripeIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconStripe()
        return imageView
    }()

    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .clear
        return tableView
    }()

    let contentView = UIView()

    let closeButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconClose(), for: .normal)
        button.isHidden = true
        return button
    }()

    let filterButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(R.image.iconFilter(), for: .normal)
        return button
    }()

    let headerView = UIView()

    let headerStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        return stackView
    }()

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
        addSubview(containerView)
        containerView.addSubview(backgroundView)
        containerView.addSubview(headerView)
        containerView.addSubview(contentView)
        containerView.addSubview(tableView)
        containerView.addSubview(stripeIconImageView)

        headerView.addSubview(headerStackView)

        headerStackView.addArrangedSubview(closeButton)
        headerStackView.addArrangedSubview(titleLabel)
        headerStackView.addArrangedSubview(filterButton)

        containerView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalToSuperview().offset(UIConstants.horizontalInset)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        headerStackView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.trailing.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        stripeIconImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Constants.stripeTopOffset)
            make.centerX.equalToSuperview()
            make.size.equalTo(Constants.stripeSize)
        }

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
            make.size.equalTo(Constants.buttonSize)
        }

        filterButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.buttonSize)
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
