import UIKit
import SoraUI
import SnapKit

final class ChainAssetListViewLayout: UIView {
    private enum Constants {
        static let tableViewContentInset = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: UIConstants.actionHeight,
            right: 0
        )
    }

    var locale: Locale?

    enum ViewState {
        case normal
        case empty
    }

    var keyboardAdoptableConstraint: Constraint?

    weak var bannersView: UIView?

    var headerViewContainer: UIStackView = {
        let view = UIFactory.default.createVerticalStackView(spacing: UIConstants.bigOffset)
        view.alignment = .center
        return view
    }()

    let containerView = UIView()
    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.separatorStyle = .none
        view.contentInset = Constants.tableViewContentInset
        view.refreshControl = UIRefreshControl()
        return view
    }()

    var isAnimating = false

    // MARK: - Manage button

    let footerButton: TriangularedButton = {
        let button = TriangularedButton()
        button.triangularedView?.shadowOpacity = 0
        button.triangularedView?.fillColor = R.color.colorWhite8()!
        button.triangularedView?.highlightedFillColor = R.color.colorWhite8()!
        button.imageWithTitleView?.titleColor = R.color.colorWhite()!
        button.imageWithTitleView?.titleFont = .h4Title
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addBanners(view: UIView) {
        bannersView = view
        bannersView?.isHidden = true
        headerViewContainer.addArrangedSubview(view)
        view.snp.makeConstraints { make in
            make.width.equalToSuperview().inset(UIConstants.bigOffset)
        }
    }

    func setHeaderView() {
        tableView.setAndLayoutTableHeaderView(header: headerViewContainer)
    }

    func removeHeaderView() {
        tableView.tableHeaderView = nil
    }

    func setFooterView() {
        let size = CGSize(width: tableView.bounds.width, height: UIConstants.actionHeight + 32)
        let footerContainer = UIView(frame: CGRect(origin: .zero, size: size))
        footerContainer.addSubview(footerButton)
        footerButton.snp.remakeConstraints { make in
            make.top.bottom.equalToSuperview().inset(16)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }
        tableView.tableFooterView = footerContainer
    }

    func removeFooterView() {
        footerButton.removeFromSuperview()
        tableView.tableFooterView = nil
    }

    func viewForEmptyState(for state: AssetListState) -> UIView {
        let emptyView = EmptyView()
        emptyView.image = R.image.iconWarning()
        emptyView.title = R.string.localizable.emptyViewTitle(preferredLanguages: locale?.rLanguages)
        emptyView.text = emptyViewText(for: state)
        emptyView.iconMode = .bigFilledShadow

        let container = ScrollableContainerView()
        container.stackView.spacing = 0
        container.stackView.alignment = .fill
        container.stackView.distribution = .equalSpacing
        container.scrollBottomOffset = 116
        container.addArrangedSubview(headerViewContainer)
        container.addArrangedSubview(emptyView)
        container.addArrangedSubview(footerButton)

        headerViewContainer.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.width.equalToSuperview()
        }

        container.stackView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
            make.height.greaterThanOrEqualToSuperview()
        }

        footerButton.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(UIConstants.actionHeight)
        }

        return container
    }

    func runManageAssetAnimate(finish: @escaping (() -> Void)) {
        isAnimating = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let rect = self.tableView.convert(
                self.footerButton.bounds,
                from: self.tableView.tableFooterView
            )
            self.tableView.scrollRectToVisible(
                rect,
                animated: true
            )

            UIView.animate(
                withDuration: 0.6,
                delay: 0.2,
                animations: {
                    self.footerButton.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                },
                completion: { _ in
                    UIView.animate(withDuration: 0.6) {
                        self.footerButton.transform = CGAffineTransform.identity
                        finish()
                        self.isAnimating = false
                    }
                }
            )
        }
    }

    func setFooterButtonTitle(for state: AssetListState) {
        let title: String?
        switch state {
        case .defaultList, .allIsHidden:
            title = R.string.localizable.walletManageAssets(preferredLanguages: locale?.rLanguages)
        case .chainHasNetworkIssue:
            title = R.string.localizable.tryAgain(preferredLanguages: locale?.rLanguages)
        case .chainHasAccountIssue:
            title = R.string.localizable.accountsAddAccount(preferredLanguages: locale?.rLanguages)
        case .search:
            title = nil
        }
        footerButton.imageWithTitleView?.title = title
    }

    private func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            keyboardAdoptableConstraint = make.bottom.equalToSuperview().constraint
        }

        containerView.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func emptyViewText(for state: AssetListState) -> String? {
        switch state {
        case .defaultList:
            return nil
        case .allIsHidden:
            return R.string.localizable.walletAllAssetsHidden(preferredLanguages: locale?.rLanguages)
        case .chainHasNetworkIssue:
            return "Connection Error: Unable to connect to the network. Please try again."
        case .chainHasAccountIssue:
            return R.string.localizable.accountNeededMessage(preferredLanguages: locale?.rLanguages)
        case .search:
            return R.string.localizable.emptyViewDescription(preferredLanguages: locale?.rLanguages)
        }
    }
}
