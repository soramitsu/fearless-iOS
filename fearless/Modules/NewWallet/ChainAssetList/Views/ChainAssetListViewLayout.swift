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

    enum ViewState {
        case normal
        case empty
    }

    var keyboardAdoptableConstraint: Constraint?

    weak var bannersView: UIView?

    var headerViewContainer: UIStackView = {
        UIFactory.default.createVerticalStackView(spacing: UIConstants.bigOffset)
    }()

    let tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .grouped)
        view.backgroundColor = .clear
        view.separatorStyle = .none
        view.contentInset = Constants.tableViewContentInset
        view.refreshControl = UIRefreshControl()
        return view
    }()

    var isAnimating = false

    // MARK: - Manage button

    let assetManagementButton: TriangularedButton = {
        let button = TriangularedButton()
        button.triangularedView?.shadowOpacity = 0
        button.triangularedView?.fillColor = R.color.colorWhite8()!
        button.triangularedView?.highlightedFillColor = R.color.colorWhite8()!
        button.imageWithTitleView?.titleColor = R.color.colorWhite()!
        button.imageWithTitleView?.titleFont = .h4Title
        button.imageWithTitleView?.title = "Manage assets"
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
            make.leading.trailing.equalToSuperview()
        }
    }

    func setFooterView() {
        let size = CGSize(width: tableView.bounds.width, height: UIConstants.actionHeight)
        let footerContainer = UIView(frame: CGRect(origin: .zero, size: size))
        footerContainer.addSubview(assetManagementButton)
        assetManagementButton.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }
        tableView.tableFooterView = footerContainer
    }

    func runManageAssetAnimate(finish: @escaping (() -> Void)) {
        isAnimating = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let rect = self.tableView.convert(
                self.assetManagementButton.bounds,
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
                    self.assetManagementButton.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                },
                completion: { _ in
                    UIView.animate(withDuration: 0.6) {
                        self.assetManagementButton.transform = CGAffineTransform.identity
                        finish()
                        self.isAnimating = false
                    }
                }
            )
        }
    }

    private func setupLayout() {
        tableView.tableHeaderView = headerViewContainer
        headerViewContainer.snp.makeConstraints { make in
            make.width.equalToSuperview().inset(UIConstants.bigOffset)
            make.centerX.equalToSuperview()
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            keyboardAdoptableConstraint = make.bottom.equalToSuperview().constraint
        }
    }
}
