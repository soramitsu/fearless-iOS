import UIKit

final class NetworkIssuesNotificationViewLayout: UIView {
    private enum Constants {
        static let cornerRadius: CGFloat = 20.0
        static let headerHeight: CGFloat = 56.0
        static let closeButtonSize: CGFloat = 32.0
        static let imageViewContainerSize: CGFloat = 80.0
        static let imageViewSize = CGSize(width: 48, height: 42)
    }

    private let navView = UIView()
    let closeButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconClose(), for: .normal)
        button.backgroundColor = R.color.colorWhite8()
        button.layer.cornerRadius = Constants.closeButtonSize / 2
        button.clipsToBounds = true
        return button
    }()

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconWarningBig()
        return imageView
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        return label
    }()

    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: 80,
            right: 0
        )
        return tableView
    }()

    let bottomCloseButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocalization() {
        bottomCloseButton.imageWithTitleView?.title = R.string.localizable.commonClose(
            preferredLanguages: locale.rLanguages
        )
        titleLabel.text = R.string.localizable.networkIssueStub(preferredLanguages: locale.rLanguages)
    }

    private func setupLayout() {
        backgroundColor = R.color.colorBlack19()
        layer.cornerRadius = Constants.cornerRadius
        clipsToBounds = true

        addSubview(navView)
        navView.snp.makeConstraints { make in
            make.height.equalTo(Constants.headerHeight)
            make.leading.trailing.top.equalToSuperview()
        }

        navView.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.closeButtonSize)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        navView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        let imageViewContainer = UIView()
        imageViewContainer.backgroundColor = R.color.colorBlack()
        imageViewContainer.layer.cornerRadius = Constants.imageViewContainerSize / 2
        imageViewContainer.layer.shadowColor = R.color.colorOrange()!.cgColor
        imageViewContainer.layer.shadowRadius = 12
        imageViewContainer.layer.shadowOpacity = 0.5
        imageViewContainer.snp.makeConstraints { make in
            make.size.equalTo(80)
        }

        imageViewContainer.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-3)
            make.size.equalTo(Constants.imageViewSize)
        }

        addSubview(imageViewContainer)
        imageViewContainer.snp.makeConstraints { make in
            make.top.equalTo(navView.snp.bottom).offset(44)
            make.centerX.equalToSuperview()
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(imageViewContainer.snp.bottom).offset(44)
            make.leading.trailing.equalToSuperview().inset(UIConstants.verticalInset)
            make.bottom.greaterThanOrEqualToSuperview().inset(UIConstants.bigOffset)
        }

        addSubview(bottomCloseButton)
        bottomCloseButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
            make.leading.trailing.equalToSuperview().inset(UIConstants.verticalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }
    }
}
