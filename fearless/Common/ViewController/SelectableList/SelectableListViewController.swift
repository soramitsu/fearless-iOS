import UIKit
import SoraFoundation
import SnapKit

class SelectableListViewController<C: UITableViewCell & SelectionItemViewProtocol>:
    UIViewController,
    UITableViewDataSource,
    UITableViewDelegate,
    ViewHolder,
    KeyboardViewAdoptable {
    typealias RootViewType = SelectableListViewLayout

    var keyboardHandler: FearlessKeyboardHandler?

    // MARK: Private properties

    private let listPresenter: SelectionListPresenterProtocol

    // MARK: - Constructor

    init(listPresenter: SelectionListPresenterProtocol) {
        self.listPresenter = listPresenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = SelectableListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView()
        bindSearchTextView()
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

    private func configureTableView() {
        rootView.tableView.registerClassForCell(C.self)
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.allowsSelection = true
    }

    private func bindSearchTextView() {
        rootView.searchTextField.onTextDidChanged = { [weak self] text in
            self?.listPresenter.searchItem(with: text)
        }
    }

    // MARK: - UITableView DataSource

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        listPresenter.numberOfItems
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellWithType(C.self) else {
            return UITableViewCell()
        }
        cell.delegate = listPresenter
        let viewModel = listPresenter.item(at: indexPath.row)
        cell.bind(viewModel: viewModel)
        return cell
    }

    // MARK: - UITableView Delegate

    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? C else {
            return
        }
        let viewModel = listPresenter.item(at: indexPath.row)
        cell.bind(viewModel: viewModel)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        listPresenter.selectItem(at: indexPath.row)
    }

    // MARK: - KeyboardViewAdoptable

    var target: Constraint? { rootView.keyboardAdoptableConstraint }

    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat { 0 }
    func updateWhileKeyboardFrameChanging(_: CGRect) {}
}

// MARK: - SelectionListViewProtocol

extension SelectableListViewController: SelectionListViewProtocol {
    func bind(viewModel: TextSearchViewModel?) {
        rootView.bind(viewModel: viewModel)
    }

    func didReload() {
        rootView.tableView.reloadData()
        rootView.setEmptyView(vasible: listPresenter.numberOfItems == 0)
    }

    func didReloadCell(at indexPath: IndexPath) {
        rootView.tableView.reloadRows(at: [indexPath], with: .automatic)
    }
}
