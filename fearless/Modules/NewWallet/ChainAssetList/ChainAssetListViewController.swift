import UIKit
import SoraFoundation
import SnapKit
import SoraUI

final class ChainAssetListViewController:
    UIViewController,
    ViewHolder,
    KeyboardViewAdoptable {
    enum Constants {
        static let sectionHeaderHeight: CGFloat = 44
    }

    typealias RootViewType = ChainAssetListViewLayout

    var keyboardHandler: FearlessKeyboardHandler?

    // MARK: Private properties

    private let output: ChainAssetListViewOutput

    private weak var bannersViewController: UIViewController?

    private var viewModel: ChainAssetListViewModel?
    private lazy var locale: Locale = {
        localizationManager?.selectedLocale ?? Locale.current
    }()

    // MARK: - Constructor

    init(
        bannersViewController: UIViewController?,
        output: ChainAssetListViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.bannersViewController = bannersViewController
        self.output = output
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = ChainAssetListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        configureTableView()
        setupEmbededViews()
        bindActions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil {
            setupKeyboardHandler()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        clearKeyboardHandler()
    }

    // MARK: - KeyboardViewAdoptable

    var target: Constraint? { rootView.keyboardAdoptableConstraint }

    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat { 0 }
    func updateWhileKeyboardFrameChanging(_: CGRect) {}
}

// MARK: - Private methods

private extension ChainAssetListViewController {
    func configureTableView() {
        rootView.tableView.registerClassForCell(ChainAccountBalanceTableCell.self)
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.estimatedRowHeight = 93

        if #available(iOS 15.0, *) {
            rootView.tableView.sectionHeaderTopPadding = 0
        }

        if let refreshControl = rootView.tableView.refreshControl {
            refreshControl.addTarget(
                self,
                action: #selector(handlePullToRefresh),
                for: .valueChanged
            )
        }
    }

    func cellViewModel(for indexPath: IndexPath) -> ChainAccountBalanceCellViewModel? {
        guard let cellModel = viewModel?.displayState.rows[safe: indexPath.row] else {
            return nil
        }
        return cellModel
    }

    func setupEmbededViews() {
        guard let bannersViewController = bannersViewController else {
            return
        }

        addChild(bannersViewController)

        rootView.addBanners(view: bannersViewController.view)
        bannersViewController.didMove(toParent: self)
    }

    func bindActions() {
        rootView.assetManagementButton.addAction { [weak self] in
            self?.output.didTapManageAsset()
        }
    }

    @objc func handlePullToRefresh() {
        output.didPullToRefresh()
        rootView.tableView.refreshControl?.endRefreshing()
    }
}

// MARK: - ChainAssetListViewInput

extension ChainAssetListViewController: ChainAssetListViewInput {
    func reloadBanners() {
        guard viewModel != nil else {
            return
        }
        rootView.tableView.setAndLayoutTableHeaderView(header: rootView.headerViewContainer)
    }

    func didReceive(viewModel: ChainAssetListViewModel) {
        self.viewModel = viewModel
        rootView.setFooterButtonTitle(for: viewModel.displayState)
        rootView.assetManagementButton.isHidden = viewModel.displayState.isSearch
        UIView.animate(withDuration: 0.3) {
            self.rootView.bannersView?.isHidden = viewModel.displayState.isSearch
        }

        switch viewModel.displayState {
        case let .defaultList(_, withAnimate):
            rootView.setHeaderView()
            rootView.setFooterView()
            guard rootView.isAnimating == false else {
                return
            }

            rootView.tableView.reloadData()

            if withAnimate {
                rootView.runManageAssetAnimate(finish: { [weak self] in
                    self?.output.didFinishManageAssetAnimate()
                    self?.rootView.tableView.reloadData()
                })
            }
        case .chainHasNetworkIssue, .chainHasAccountIssue, .allIsHidden:
            rootView.removeHeaderView()
            rootView.removeFooterView()
            rootView.tableView.reloadData()
        case .search:
            let isEmpty = viewModel.displayState.rows.isEmpty
            isEmpty ? rootView.removeFooterView() : rootView.setFooterView()
            isEmpty ? rootView.removeHeaderView() : rootView.setHeaderView()
            rootView.tableView.reloadData()
        }
        reloadEmptyState(animated: false)
    }
}

// MARK: - Localizable

extension ChainAssetListViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

extension ChainAssetListViewController: SwipableTableViewCellDelegate {
    func swipeCellDidTap(on actionType: SwipableCellButtonType, with indexPath: IndexPath?) {
        guard let indexPath = indexPath else {
            return
        }
        if let viewModelForAction = cellViewModel(for: indexPath) {
            output.didTapAction(actionType: actionType, viewModel: viewModelForAction)
        }
    }
}

// MARK: - UITableViewDelegate

extension ChainAssetListViewController: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let viewModel = cellViewModel(for: indexPath) else { return }

        output.didSelectViewModel(viewModel)
    }

    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if
            let assetCell = cell as? ChainAccountBalanceTableCell,
            let viewModel = viewModel?.displayState.rows[safe: indexPath.row] {
            assetCell.bind(to: viewModel)
        }
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        ChainAccountBalanceTableCell.LayoutConstants.cellHeight
    }

    func tableView(_: UITableView, estimatedHeightForRowAt _: IndexPath) -> CGFloat {
        93
    }
}

// MARK: - UITableViewDataSource

extension ChainAssetListViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModel?.displayState.rows.count ?? .zero
    }

    func tableView(_ tableView: UITableView, cellForRowAt _: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellWithType(ChainAccountBalanceTableCell.self) else {
            return UITableViewCell()
        }
        cell.delegate = self
        return cell
    }
}

// MARK: - EmptyStateViewOwnerProtocol

extension ChainAssetListViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

// MARK: - EmptyStateDataSource

extension ChainAssetListViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        guard let viewModel else {
            return nil
        }
        let view = rootView.viewForEmptyState(for: viewModel.displayState)
        return view
    }

    var contentViewForEmptyState: UIView {
        rootView
    }
}

// MARK: - EmptyStateDelegate

extension ChainAssetListViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        guard let viewModel = viewModel else { return false }
        return viewModel.displayState.rows.isEmpty
    }
}
