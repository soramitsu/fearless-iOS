import UIKit
import SoraUI
import SoraFoundation
import SnapKit

protocol NetworkManagmentViewOutput: NetworkManagmentTableCellDelegate {
    func didLoad(view: NetworkManagmentViewInput)
    func searchTextDidChanged(_ text: String?)
    func didSelectRow(at indexPath: IndexPath)
    func didSelectAllFilter()
    func didSelectPopularFilter()
    func didSelectFavouriteFilter()
    func didTapBackButton()
}

final class NetworkManagmentViewController: UIViewController, ViewHolder {
    typealias RootViewType = NetworkManagmentViewLayout

    var keyboardHandler: FearlessKeyboardHandler?

    // MARK: Private properties

    private let output: NetworkManagmentViewOutput

    private var viewModel: NetworkManagmentViewModel?

    // MARK: - Constructor

    init(
        output: NetworkManagmentViewOutput,
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
        view = NetworkManagmentViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        bindActions()
        configureTableView()
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
        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.didTapBackButton()
        }
        rootView.allFilterButton.addAction { [weak self] in
            self?.output.didSelectAllFilter()
        }
        rootView.popularFilterButton.addAction { [weak self] in
            self?.output.didSelectPopularFilter()
        }
        rootView.favouriteFilterButton.addAction { [weak self] in
            self?.output.didSelectFavouriteFilter()
        }
        rootView.searchTextField.onTextDidChanged = { [weak self] text in
            self?.output.searchTextDidChanged(text)
        }
    }

    private func configureTableView() {
        rootView.tableView.separatorStyle = .none
        rootView.tableView.registerClassForCell(NetworkManagmentTableCell.self)
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
    }
}

// MARK: - NetworkManagmentViewInput

extension NetworkManagmentViewController: NetworkManagmentViewInput {
    func didReceive(viewModel: NetworkManagmentViewModel) {
        self.viewModel = viewModel
        rootView.setSelected(filter: viewModel.activeFilter)
        rootView.tableView.reloadData()
        reloadEmptyState(animated: true)
    }
}

// MARK: - Localizable

extension NetworkManagmentViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - KeyboardViewAdoptable

extension NetworkManagmentViewController: KeyboardViewAdoptable {
    var target: Constraint? { rootView.keyboardAdoptableConstraint }

    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat { 0 }
    func updateWhileKeyboardFrameChanging(_: CGRect) {}
}

// MARK: - UITableViewDataSource

extension NetworkManagmentViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModel?.cells.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt _: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellWithType(NetworkManagmentTableCell.self) else {
            return UITableViewCell()
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension NetworkManagmentViewController: UITableViewDelegate {
    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard
            let viewModel = viewModel?.cells[safe: indexPath.row],
            let cell = cell as? NetworkManagmentTableCell else {
            return
        }

        cell.bind(viewModel: viewModel)
        cell.delegate = output
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        output.didSelectRow(at: indexPath)
    }
}

// MARK: - EmptyStateViewOwnerProtocol

extension NetworkManagmentViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

// MARK: - EmptyStateDataSource

extension NetworkManagmentViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        let emptyView = EmptyView()
        emptyView.image = R.image.iconWarning()
        emptyView.title = R.string.localizable
            .emptyViewTitle(preferredLanguages: selectedLocale.rLanguages)
        emptyView.text = R.string.localizable.selectNetworkSearchEmptySubtitle(preferredLanguages: selectedLocale.rLanguages)
        emptyView.iconMode = .bigFilledShadow
        emptyView.contentAlignment = ContentAlignment(vertical: .center, horizontal: .center)
        return emptyView
    }

    var contentViewForEmptyState: UIView {
        rootView.container
    }
}

// MARK: - EmptyStateDelegate

extension NetworkManagmentViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        viewModel?.cells.isEmpty == true
    }
}
