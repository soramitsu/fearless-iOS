import UIKit
import SoraFoundation
import SnapKit
import SoraUI

final class LiquidityPoolsListViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = LiquidityPoolsListViewLayout
    var keyboardHandler: FearlessKeyboardHandler?

    // MARK: Private properties

    private var cellModels: [LiquidityPoolListCellModel]?
    private let output: LiquidityPoolsListViewOutput
    private var refreshControl = UIRefreshControl()

    private var viewLoadingFinished: Bool = false

    // MARK: - Constructor

    init(
        output: LiquidityPoolsListViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
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
        view = LiquidityPoolsListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)

        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.registerClassForCell(LiquidityPoolListCell.self)

        rootView.moreButton.addAction { [weak self] in
            self?.output.didTapMoreButton()
        }

        rootView.backButton.addAction { [weak self] in
            self?.output.didTapBackButton()
        }

        bindSearchTextView()
        addEndEditingTapGesture(for: rootView)

        rootView.tableView.addSubview(refreshControl)
        refreshControl.addTarget(self, action: #selector(handleRefreshControlEvent), for: .valueChanged)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil {
            setupKeyboardHandler()
        }

        guard !viewLoadingFinished else {
            return
        }

        viewLoadingFinished = true

        output.didAppearView()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        clearKeyboardHandler()
    }

    // MARK: - Private methods

    private func bindSearchTextView() {
        rootView.searchTextField.onTextDidChanged = { [weak self] text in
            self?.output.searchTextDidChanged(text)
        }
    }

    @objc private func handleRefreshControlEvent() {
        output.handleRefreshControlEvent()
    }
}

extension LiquidityPoolsListViewController: KeyboardViewAdoptable {
    var target: Constraint? { rootView.keyboardAdoptableConstraint }

    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat { 0 }
    func updateWhileKeyboardFrameChanging(_: CGRect) {}
}

extension LiquidityPoolsListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        guard let cellModels else {
            return 0
        }

        return cellModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt _: IndexPath) -> UITableViewCell {
        tableView.dequeueReusableCellWithType(LiquidityPoolListCell.self) ?? UITableViewCell()
    }

    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let lpCell = cell as? LiquidityPoolListCell, let cellModels else {
            return
        }

        lpCell.bind(viewModel: cellModels[indexPath.row])
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        44
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let cellModels else { return }
        output.didTapOn(viewModel: cellModels[indexPath.row])
    }
}

// MARK: - LiquidityPoolsListViewInput

extension LiquidityPoolsListViewController: LiquidityPoolsListViewInput {
    func didReceive(viewModel: LiquidityPoolListViewModel) {
        refreshControl.endRefreshing()

        cellModels = viewModel.poolViewModels
        rootView.bind(viewModel: viewModel)

        rootView.tableView.reloadData()

        reloadEmptyState(animated: false)
    }
}

// MARK: - Localizable

extension LiquidityPoolsListViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - EmptyStateViewOwnerProtocol

extension LiquidityPoolsListViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

// MARK: - EmptyStateDataSource

extension LiquidityPoolsListViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        let emptyView = EmptyView()
        emptyView.image = R.image.iconWarningGray()
        emptyView.title = R.string.localizable
            .emptyViewTitle(preferredLanguages: selectedLocale.rLanguages)
        emptyView.text = R.string.localizable.selectAssetSearchEmptySubtitle(preferredLanguages: selectedLocale.rLanguages)
        emptyView.iconMode = .smallFilled
        return emptyView
    }

    var contentViewForEmptyState: UIView {
        rootView.contentView
    }
}

// MARK: - EmptyStateDelegate

extension LiquidityPoolsListViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        guard let cellModels else {
            return false
        }

        return cellModels.isEmpty
    }
}
