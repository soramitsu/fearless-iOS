import UIKit
import SoraUI
import SoraFoundation
import SnapKit

protocol AssetManagementViewOutput: AnyObject {
    func didLoad(view: AssetManagementViewInput)
    func doneButtonDidTapped()
    func searchTextDidChanged(_ text: String?)
    func allNetworkButtonDidTapped()
    func didSelectRow(at indexPath: IndexPath, viewModel: AssetManagementViewModel)
    func didTap(on section: Int, viewModel: AssetManagementViewModel)
    func didPullToRefresh()
}

final class AssetManagementViewController: UIViewController, ViewHolder, HiddableBarWhenPushed, KeyboardViewAdoptable {
    typealias RootViewType = AssetManagementViewLayout

    // MARK: Private properties

    private let output: AssetManagementViewOutput

    private var viewModel: AssetManagementViewModel?

    // MARK: - Constructor

    init(
        output: AssetManagementViewOutput,
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
        view = AssetManagementViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        configureTableView()
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

    // MARK: - Private methods

    private func bindActions() {
        rootView.filterNetworksButton.addAction { [weak self] in
            self?.output.allNetworkButtonDidTapped()
        }
        rootView.doneButton.addAction { [weak self] in
            self?.output.doneButtonDidTapped()
        }
        rootView.searchTextField.onTextDidChanged = { [weak self] text in
            self?.output.searchTextDidChanged(text)
        }
    }

    private func configureTableView() {
        rootView.tableView.separatorStyle = .none
        rootView.tableView.registerClassForCell(AssetManagementTableCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: AssetManagementTableHeaderView.self)
        rootView.tableView.rowHeight = 55
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self

        rootView.tableView.estimatedRowHeight = 0
        rootView.tableView.estimatedSectionHeaderHeight = 0
        rootView.tableView.estimatedSectionFooterHeight = 0

        rootView.tableView.contentInsetAdjustmentBehavior = .never

        if let refreshControl = rootView.tableView.refreshControl {
            refreshControl.addTarget(
                self,
                action: #selector(handlePullToRefresh),
                for: .valueChanged
            )
        }
    }

    // MARK: - Actions

    @objc
    private func handleTap(sender: UIGestureRecognizer) {
        guard let viewModel, let section = sender.view?.tag else {
            return
        }
        output.didTap(on: section, viewModel: viewModel)
    }

    @objc
    private func handlePullToRefresh() {
        output.didPullToRefresh()
    }

    // MARK: - KeyboardViewAdoptable

    var target: Constraint? { rootView.keyboardAdoptableConstraint }

    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat { 0 }
    func updateWhileKeyboardFrameChanging(_: CGRect) {}
}

// MARK: - AssetManagementViewInput

extension AssetManagementViewController: AssetManagementViewInput {
    func didReceive(viewModel: AssetManagementViewModel) {
        self.viewModel = viewModel
        rootView.setFilter(title: viewModel.filterButtonTitle)
        rootView.setAddAssetButton(visible: viewModel.addAssetButtonIsHidden)
        rootView.tableView.reloadData()
        rootView.tableView.refreshControl?.endRefreshing()
        reloadEmptyState(animated: false)
    }

    func didReceive(viewModel: AssetManagementViewModel, on section: Int) {
        self.viewModel = viewModel

        rootView.tableView.beginUpdates()
        let indexSet = IndexSet(integer: section)
        rootView.tableView.reloadSections(indexSet, with: .automatic)
        rootView.tableView.endUpdates()
    }
}

// MARK: - Localizable

extension AssetManagementViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - UITableViewDataSource

extension AssetManagementViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        viewModel?.list.count ?? .zero
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = viewModel?.list[safe: section] else {
            return .zero
        }

        guard section.hasView else {
            return section.cells.count
        }

        if section.isExpanded {
            return section.cells.count
        } else {
            return .zero
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt _: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellWithType(AssetManagementTableCell.self) else {
            return UITableViewCell()
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension AssetManagementViewController: UITableViewDelegate {
    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard
            let cell = cell as? AssetManagementTableCell,
            let section = viewModel?.list[safe: indexPath.section],
            let viewModel = section.cells[safe: indexPath.row]
        else {
            return
        }
        cell.bind(viewModel: viewModel)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        guard let viewModel else {
            return
        }
        output.didSelectRow(at: indexPath, viewModel: viewModel)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard
            let section = viewModel?.list[safe: section],
            section.hasView
        else {
            return UIView()
        }
        let view: AssetManagementTableHeaderView = tableView.dequeueReusableHeaderFooterView()
        view.bind(viewModel: section)

        return view
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard viewModel?.list[section].hasView == true else {
            return .leastNormalMagnitude
        }
        return 55
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        .leastNormalMagnitude
    }

    func tableView(_: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTap(sender:))
        )
        tapGesture.numberOfTapsRequired = 1
        tapGesture.numberOfTouchesRequired = 1
        view.addGestureRecognizer(tapGesture)
        tapGesture.view?.tag = section
    }
}

// MARK: - EmptyStateViewOwnerProtocol

extension AssetManagementViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

// MARK: - EmptyStateDataSource

extension AssetManagementViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        let emptyView = EmptyView()
        emptyView.image = R.image.iconWarningGray()
        emptyView.title = R.string.localizable
            .emptyViewTitle(preferredLanguages: selectedLocale.rLanguages)
        emptyView.text = R.string.localizable.emptyViewDescription(preferredLanguages: selectedLocale.rLanguages)
        emptyView.iconMode = .smallFilled
        return emptyView
    }

    var contentViewForEmptyState: UIView {
        rootView.container
    }
}

// MARK: - EmptyStateDelegate

extension AssetManagementViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        guard let viewModel = viewModel else { return false }
        return viewModel.list.isEmpty
    }
}
