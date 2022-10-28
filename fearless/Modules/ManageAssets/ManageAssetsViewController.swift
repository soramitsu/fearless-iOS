import UIKit
import MobileCoreServices
import SnapKit

final class ManageAssetsViewController: UIViewController, ViewHolder {
    private enum LayoutConstants {
        static let cellHeight: CGFloat = 55
    }

    typealias RootViewType = ManageAssetsViewLayout

    let presenter: ManageAssetsPresenterProtocol

    var state: ManageAssetsViewState = .loading

    private var isFirstLayoutCompleted: Bool = false

    init(presenter: ManageAssetsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ManageAssetsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()

        configure()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupKeyboardHandler()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        clearKeyboardHandler()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        isFirstLayoutCompleted = true
    }

    private func applyState() {
        switch state {
        case .loading:
            break
        case let .loaded(viewModel):
            rootView.bind(viewModel: viewModel)
            rootView.tableView.reloadData()
        }
    }

    private func configure() {
        rootView.searchBar.delegate = self

        rootView.tableView.registerClassForCell(ManageAssetsTableViewCell.self)

        rootView.tableView.tableFooterView = UIView()

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.dragDelegate = self
        rootView.tableView.dragInteractionEnabled = true

        rootView.applyButton.addTarget(self, action: #selector(applyButtonClicked), for: .touchUpInside)

        let filterButton = UIBarButtonItem(
            image: R.image.manageAssetsFilterIcon(),
            style: .plain,
            target: self,
            action: #selector(filterButtonClicked)
        )
        navigationItem.rightBarButtonItem = filterButton

        rootView.chainSelectionView.addTarget(
            self,
            action: #selector(selectChainButtonClicked),
            for: .touchUpInside
        )
    }

    @objc private func filterButtonClicked() {
        presenter.didTapFilterButton()
    }

    @objc private func selectChainButtonClicked() {
        presenter.didTapChainSelectButton()
    }

    @objc private func applyButtonClicked() {
        presenter.didTapApplyButton()
    }
}

extension ManageAssetsViewController: ManageAssetsViewProtocol {
    func didReceive(state: ManageAssetsViewState) {
        self.state = state
        applyState()
    }

    func didReceive(locale: Locale) {
        rootView.locale = locale

        title = R.string.localizable.walletManageAssets(preferredLanguages: locale.rLanguages)
    }
}

extension ManageAssetsViewController: UITableViewDataSource {
    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        LayoutConstants.cellHeight
    }

    func numberOfSections(in _: UITableView) -> Int {
        guard case .loaded = state else {
            return 0
        }

        return 2
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard case let .loaded(viewModel) = state else {
            return 0
        }

        return viewModel.sections[section].cellModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard case let .loaded(viewModel) = state else {
            return UITableViewCell()
        }

        guard let cell = tableView.dequeueReusableCellWithType(ManageAssetsTableViewCell.self)
        else {
            return UITableViewCell()
        }

        let cellModel = viewModel.sections[indexPath.section].cellModels[indexPath.row]
        cell.bind(to: cellModel)
        return cell
    }

    func tableView(_: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard case let .loaded(viewModel) = state else {
            return
        }

        let cellModel = viewModel.sections[sourceIndexPath.section].cellModels[sourceIndexPath.row]
        presenter.move(
            from: sourceIndexPath,
            to: destinationIndexPath
        )
    }
}

extension ManageAssetsViewController: UITableViewDelegate {}

extension ManageAssetsViewController: UITableViewDragDelegate {
    func tableView(_: UITableView, itemsForBeginning _: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard case let .loaded(viewModel) = state else {
            return []
        }

        let cellModel = viewModel.sections[indexPath.section].cellModels[indexPath.row]

        let dragItem = UIDragItem(itemProvider: NSItemProvider())
        dragItem.localObject = cellModel
        return [dragItem]
    }
}

extension ManageAssetsViewController: UISearchBarDelegate {
    func searchBar(_: UISearchBar, textDidChange searchText: String) {
        presenter.searchBarTextDidChange(searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

extension ManageAssetsViewController: KeyboardViewAdoptable {
    var target: Constraint? { rootView.keyboardAdoptableConstraint }

    var shouldApplyKeyboardFrame: Bool { isFirstLayoutCompleted }

    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat {
        UIConstants.bigOffset
    }

    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        if let responder = rootView.firstResponder {
            var inset = rootView.tableView.contentInset
            var responderFrame: CGRect
            responderFrame = responder.convert(responder.frame, to: rootView.tableView)

            if frame.height == 0 {
                inset.bottom = 0
                rootView.tableView.contentInset = inset
            } else {
                inset.bottom = frame.height + UIConstants.actionHeight
                rootView.tableView.contentInset = inset
            }
            rootView.tableView.scrollRectToVisible(responderFrame, animated: true)
        }
    }
}
