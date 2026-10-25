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
    func didSelectVisibilityFilter(_ filter: ManageAssetsFilter)
    func didToggleGroup(on section: Int, viewModel: AssetManagementViewModel)
    func didResetToAutomatic(at indexPath: IndexPath, viewModel: AssetManagementViewModel)
    func didTapResetOrder()
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
        rootView.resetOrderButton.addAction { [weak self] in self?.output.didTapResetOrder() }
        for (filter, button) in rootView.visibilityFilterButtons {
            button.addAction { [weak self] in self?.output.didSelectVisibilityFilter(filter) }
        }
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
        rootView.tableView.rowHeight = UITableView.automaticDimension
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self

        rootView.tableView.estimatedRowHeight = 55
        rootView.tableView.estimatedSectionHeaderHeight = 55
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
        rootView.setVisibilityFilter(viewModel.visibilityFilter)
        rootView.resetOrderButton.isHidden = !viewModel.canResetOrder
        rootView.setAddAssetButton(visible: viewModel.addAssetButtonIsHidden)
        rootView.tableView.reloadData()
        rootView.tableView.refreshControl?.endRefreshing()
        rootView.emptyResultsLabel.isHidden = !viewModel.list.isEmpty
        rootView.setNeedsLayout()
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

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellWithType(AssetManagementTableCell.self) else {
            return UITableViewCell()
        }
        if let viewModel, let model = viewModel.list[safe: indexPath.section]?.cells[safe: indexPath.row] {
            cell.bind(viewModel: model)
            cell.accessibilityCustomActions = [UIAccessibilityCustomAction(name: PortfolioStrings.text("manage_assets.reset_auto", locale: selectedLocale)) { [weak self] _ in
                guard let self else { return false }
                self.output.didResetToAutomatic(at: indexPath, viewModel: viewModel)
                return true
            }]
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension AssetManagementViewController: UITableViewDelegate {
    func tableView(_: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let viewModel, viewModel.list[safe: indexPath.section]?.cells[safe: indexPath.row] != nil else { return nil }
        let action = UIContextualAction(style: .normal, title: PortfolioStrings.text("manage_assets.reset_auto", locale: selectedLocale)) { [weak self] _, _, completion in
            guard let self else { completion(false); return }
            self.output.didResetToAutomatic(at: indexPath, viewModel: viewModel)
            completion(true)
        }
        let configuration = UISwipeActionsConfiguration(actions: [action])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
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
        view.bind(viewModel: section, locale: selectedLocale)
        if let model = viewModel {
            view.onToggleVisibility = { [weak self] in self?.output.didToggleGroup(on: model.list.firstIndex(where: { $0.id == section.id }) ?? -1, viewModel: model) }
            view.onToggleExpansion = { [weak self] in self?.output.didTap(on: model.list.firstIndex(where: { $0.id == section.id }) ?? -1, viewModel: model) }
        }

        return view
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard viewModel?.list[section].hasView == true else {
            return .leastNormalMagnitude
        }
        return UITableView.automaticDimension
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        .leastNormalMagnitude
    }

    func tableView(_: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        view.gestureRecognizers?.filter { $0 is UITapGestureRecognizer }.forEach(view.removeGestureRecognizer)
        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTap(sender:))
        )
        tapGesture.delegate = self
        tapGesture.numberOfTapsRequired = 1
        tapGesture.numberOfTouchesRequired = 1
        view.addGestureRecognizer(tapGesture)
        tapGesture.view?.tag = section
    }
}

extension AssetManagementViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var target = touch.view
        while let view = target {
            if view is UIControl { return false }
            target = view.superview
        }
        return true
    }
}
