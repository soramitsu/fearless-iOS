import UIKit

final class StakingPoolJoinChoosePoolViewLayout: UIView {
    private enum LayoutConstants {
        static let optionsButtonSize = CGSize(width: 32.0, height: 32.0)
    }

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.refreshControl = UIRefreshControl()
        view.separatorStyle = .none
        view.contentInset = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: UIConstants.bigOffset + UIConstants.actionHeight + UIConstants.bigOffset,
            right: 0
        )

        return view
    }()

    let continueButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.set(.push)
        bar.backButton.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.08)
        bar.backButton.layer.cornerRadius = bar.backButton.frame.size.height / 2
        bar.backgroundColor = R.color.colorAlmostBlack()
        return bar
    }()

    let optionsButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconHorMore(), for: .normal)
        button.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.08)
        button.layer.cornerRadius = button.frame.size.height / 2
        return button
    }()

    let emptyView: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 2
        label.isHidden = true
        return label
    }()

    var locale = Locale.current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorAlmostBlack()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        navigationBar.backButton.layer.cornerRadius = navigationBar.backButton.frame.size.height / 2
        optionsButton.layer.cornerRadius = optionsButton.frame.size.height / 2
    }

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(tableView)
        addSubview(continueButton)
        addSubview(emptyView)

        navigationBar.setRightViews([optionsButton])

        optionsButton.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.optionsButtonSize)
            make.trailing.equalToSuperview().offset(UIConstants.defaultOffset)
        }

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        tableView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.bigOffset)
        }

        continueButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        emptyView.snp.makeConstraints { make in
            make.center.equalTo(tableView.snp.center)
        }
    }

    private func applyLocalization() {
        continueButton.imageWithTitleView?.title = R.string.localizable.poolStakingChoosepoolButtonTitle(
            preferredLanguages: locale.rLanguages
        )
        navigationBar.setTitle(R.string.localizable.poolStakingChoosepoolTitle(
            preferredLanguages: locale.rLanguages
        ))
        emptyView.text = R.string.localizable.choosePoolEmptyTitle(preferredLanguages: locale.rLanguages)
    }
}
