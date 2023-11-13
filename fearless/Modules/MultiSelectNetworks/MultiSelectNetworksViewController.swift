import UIKit
import SoraUI
import SoraFoundation
import SnapKit

protocol MultiSelectNetworksViewOutput: AnyObject {
    func didLoad(view: MultiSelectNetworksViewInput)
    func selectAllDidTapped()
    func doneButtonDidTapped()
    func searchTextDidChanged(_ text: String?)
    func didSelectRow(at indexPath: IndexPath)
}

final class MultiSelectNetworksViewController: UIViewController, ViewHolder {
    typealias RootViewType = MultiSelectNetworksViewLayout

    var keyboardHandler: FearlessKeyboardHandler?

    // MARK: Private properties

    private let output: MultiSelectNetworksViewOutput

    private var viewModel: MultiSelectNetworksViewModel?

    // MARK: - Constructor

    init(
        output: MultiSelectNetworksViewOutput,
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
        view = MultiSelectNetworksViewLayout()
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
        rootView.selectAllButton.addAction { [weak self] in
            self?.output.selectAllDidTapped()
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
        rootView.tableView.registerClassForCell(MultiSelectNetworksTableCell.self)
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
    }
}

// MARK: - MultiSelectNetworksViewInput

extension MultiSelectNetworksViewController: MultiSelectNetworksViewInput {
    func didReceive(viewModel: MultiSelectNetworksViewModel) {
        if self.viewModel?.allIsSelected != viewModel.allIsSelected {
            rootView.handleSelectAllButton(allSelected: viewModel.allIsSelected)
        }
        rootView.setTitle(text: viewModel.selectedCountTitle)
        self.viewModel = viewModel
        rootView.tableView.reloadData()
        reloadEmptyState(animated: false)
    }
}

// MARK: - Localizable

extension MultiSelectNetworksViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - KeyboardViewAdoptable

extension MultiSelectNetworksViewController: KeyboardViewAdoptable {
    var target: Constraint? { rootView.keyboardAdoptableConstraint }

    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat { 0 }
    func updateWhileKeyboardFrameChanging(_: CGRect) {}
}

// MARK: - UITableViewDataSource

extension MultiSelectNetworksViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModel?.cells.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt _: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellWithType(MultiSelectNetworksTableCell.self) else {
            return UITableViewCell()
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension MultiSelectNetworksViewController: UITableViewDelegate {
    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard
            let viewModel = viewModel?.cells[indexPath.row],
            let cell = cell as? MultiSelectNetworksTableCell else {
            return
        }

        cell.bind(viewModel: viewModel)
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        output.didSelectRow(at: indexPath)
    }
}

// MARK: - EmptyStateViewOwnerProtocol

extension MultiSelectNetworksViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

// MARK: - EmptyStateDataSource

extension MultiSelectNetworksViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        let emptyView = EmptyView()
        emptyView.image = R.image.iconWarning()
        emptyView.title = R.string.localizable
            .emptyViewTitle(preferredLanguages: selectedLocale.rLanguages)
        emptyView.text = R.string.localizable.emptyStateMessage(preferredLanguages: selectedLocale.rLanguages)
        emptyView.iconMode = .bigFilledShadow
        emptyView.contentAlignment = ContentAlignment(vertical: .center, horizontal: .center)
        return emptyView
    }

    var contentViewForEmptyState: UIView {
        rootView.container
    }
}

// MARK: - EmptyStateDelegate

extension MultiSelectNetworksViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        viewModel?.cells.isEmpty == true
    }
}
