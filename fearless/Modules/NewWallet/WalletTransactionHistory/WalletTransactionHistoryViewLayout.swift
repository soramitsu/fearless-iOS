import UIKit
import SoraUI
import SnapKit

final class WalletTransactionHistoryViewLayout: UIView {
    enum Constants {
        static let buttonSize: CGFloat = 40
        static let stripeSize = CGSize(width: 35, height: 2)
        static let stripeTopOffset: CGFloat = 2
        static let separatorHeight: CGFloat = 1
    }

    let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.backgroundImage()
        imageView.alpha = 0
        return imageView
    }()

    let typeSwitcherContainer: UIView = {
        let view = UIView()
        view.isHidden = true
        return view
    }()

    let typeSwitcher = FWSegmentedControl()

    private let containerView = UIView()
    private let backgroundView: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = R.color.colorWhite4()!
        view.highlightedFillColor = R.color.colorWhite4()!
        view.shadowOpacity = 0
        return view
    }()

    private let stripeIconImageView: UIImageView = {
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

    private let headerTopStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        return stackView
    }()

    private let headerContentStackView = UIFactory.default.createVerticalStackView(spacing: 4)

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p0Paragraph
        return label
    }()

    let panIndicatorView = RoundedView()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorWhite8()
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        applyLocalization()
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

        addSubview(containerView)
        containerView.addSubview(backgroundView)
        containerView.addSubview(headerView)
        containerView.addSubview(contentView)
        containerView.addSubview(tableView)
        containerView.addSubview(stripeIconImageView)

        headerView.addSubview(headerContentStackView)
        headerContentStackView.addArrangedSubview(headerTopStackView)
        headerContentStackView.addArrangedSubview(typeSwitcherContainer)
        typeSwitcherContainer.addSubview(typeSwitcher)
        headerContentStackView.addArrangedSubview(separatorView)

        headerTopStackView.addArrangedSubview(closeButton)
        headerTopStackView.addArrangedSubview(titleLabel)
        headerTopStackView.addArrangedSubview(filterButton)

        containerView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
        }

        headerTopStackView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        stripeIconImageView.snp.makeConstraints { make in
            make.top.equalTo(backgroundView.snp.top).offset(Constants.stripeTopOffset)
            make.centerX.equalToSuperview()
            make.size.equalTo(Constants.stripeSize)
        }

        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview().offset(UIConstants.horizontalInset)
        }

        headerView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.horizontalInset)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        typeSwitcher.snp.makeConstraints { make in
            make.height.equalTo(32)
            make.width.equalTo(contentView.snp.width).offset(-2.0 * UIConstants.horizontalInset)
            make.edges.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.horizontalInset)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview()
            make.top.equalTo(headerView.snp.bottom)
        }

        tableView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.horizontalInset)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview()
            make.top.equalTo(headerView.snp.bottom)
        }

        closeButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.buttonSize)
        }

        filterButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.buttonSize)
        }

        separatorView.snp.makeConstraints { make in
            make.height.equalTo(Constants.separatorHeight)
            make.leading.trailing.equalTo(headerTopStackView)
        }

        headerContentStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func setHeaderHeight(_ height: CGFloat) {
        headerView.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.horizontalInset)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview()
            make.height.equalTo(height)
        }
    }

    func setHeaderTopOffset(_ offset: CGFloat) {
        headerView.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.horizontalInset)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().offset(offset)
        }
    }

    func update(tableViewOffset: CGFloat) {
        backgroundView.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(tableViewOffset)
            make.trailing.equalToSuperview().inset(tableViewOffset)
            make.top.equalToSuperview().offset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview().inset(UIConstants.horizontalInset)
        }
    }

    private func applyLocalization() {
        typeSwitcher.setSegmentItems([R.string.localizable.walletFiltersTransfers(preferredLanguages: locale.rLanguages),
                                      R.string.localizable.stakingRewardsTitle(preferredLanguages: locale.rLanguages),
                                      R.string.localizable.tranactionHistoryOthersTabTitle(preferredLanguages: locale.rLanguages)])
    }
}
