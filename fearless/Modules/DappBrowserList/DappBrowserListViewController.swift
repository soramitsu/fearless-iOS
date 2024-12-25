import UIKit
import SoraUI
import SnapKit
import SoraFoundation

protocol DappBrowserListViewOutput: AnyObject {
    func didLoad(view: DappBrowserListViewInput)
    func searchTextDidChanged(_ text: String?)
    func didTapBackButton()
    func didSelect(dapp: TonDapp)
}

final class DappBrowserListViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = DappBrowserListViewLayout
    var keyboardHandler: FearlessKeyboardHandler?

    // MARK: Private properties

    private let output: DappBrowserListViewOutput

    var viewModels: [DappBrowserListCellViewModel] = []

    // MARK: - Constructor

    init(
        title: String,
        output: DappBrowserListViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.output = output
        super.init(nibName: nil, bundle: nil)
        rootView.navigationBar.setTitle(title)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = DappBrowserListViewLayout()
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
        rootView.searchTextField.onTextDidChanged = { [weak self] text in
            self?.output.searchTextDidChanged(text)
        }
    }

    private func configureTableView() {
        rootView.tableView.separatorStyle = .none
        rootView.tableView.registerClassForCell(DappBrowserListCell.self)
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.rowHeight = 64
    }
}

// MARK: - DappBrowserListViewInput

extension DappBrowserListViewController: DappBrowserListViewInput {
    func didReceive(viewModels: [DappBrowserListCellViewModel]) {
        self.viewModels = viewModels
        rootView.tableView.reloadData()
        reloadEmptyState(animated: true)
    }
}

// MARK: - Localizable

extension DappBrowserListViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - KeyboardViewAdoptable

extension DappBrowserListViewController: KeyboardViewAdoptable {
    var target: Constraint? { rootView.keyboardAdoptableConstraint }

    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat { 0 }
    func updateWhileKeyboardFrameChanging(_: CGRect) {}
}

// MARK: - UITableViewDataSource

extension DappBrowserListViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard
            let viewModel = viewModels[safe: indexPath.row],
            let cell = tableView.dequeueReusableCellWithType(DappBrowserListCell.self)
        else {
            return UITableViewCell()
        }
        cell.configure(model: viewModel, position: .list)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension DappBrowserListViewController: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let viewModel = viewModels[safe: indexPath.row] else {
            return
        }
        let dapp = viewModel.dapp
        output.didSelect(dapp: dapp)
    }
}

// MARK: - EmptyStateViewOwnerProtocol

extension DappBrowserListViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

// MARK: - EmptyStateDataSource

extension DappBrowserListViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        let emptyView = EmptyView()
        emptyView.image = R.image.iconWarning()
        emptyView.title = R.string.localizable
            .emptyViewTitle(preferredLanguages: selectedLocale.rLanguages)
        emptyView.text = R.string.localizable.dappNotFoundTitle(preferredLanguages: selectedLocale.rLanguages)
        emptyView.iconMode = .bigFilledShadow
        return emptyView
    }

    var contentViewForEmptyState: UIView {
        rootView.container
    }
}

// MARK: - EmptyStateDelegate

extension DappBrowserListViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        viewModels.isEmpty
    }
}
