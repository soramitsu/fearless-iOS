import UIKit
import MobileCoreServices

final class ManageAssetsViewController: UIViewController, ViewHolder {
    typealias RootViewType = ManageAssetsViewLayout

    let presenter: ManageAssetsPresenterProtocol

    var state: ManageAssetsViewState = .loading

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

    private func applyState() {
        switch state {
        case .loading:
            break
        case .loaded:
            rootView.tableView.reloadData()
        }
    }

    private func configure() {
        rootView.tableView.registerClassForCell(ManageAssetsTableViewCell.self)

        rootView.tableView.tableFooterView = UIView()

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.dragDelegate = self
        rootView.tableView.dragInteractionEnabled = true

        rootView.navigationBar.backButton.addTarget(self, action: #selector(backButtonClicked), for: .touchUpInside)
    }

    @objc private func backButtonClicked() {
        presenter.didTapCloseButton()
    }
}

extension ManageAssetsViewController: ManageAssetsViewProtocol {
    func didReceive(state: ManageAssetsViewState) {
        self.state = state
        applyState()
    }

    func didReceive(locale: Locale) {
        rootView.locale = locale
    }
}

extension ManageAssetsViewController: UITableViewDataSource {
    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        55
    }

    func numberOfSections(in _: UITableView) -> Int {
        guard case .loaded = state else {
            return 0
        }

        return 1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        guard case let .loaded(viewModel) = state else {
            return 0
        }

        return viewModel.cellModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard case let .loaded(viewModel) = state else {
            return UITableViewCell()
        }

        guard let cell = tableView.dequeueReusableCellWithType(ManageAssetsTableViewCell.self)
        else {
            return UITableViewCell()
        }

        cell.bind(to: viewModel.cellModels[indexPath.row])
        return cell
    }

    func tableView(_: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard case let .loaded(viewModel) = state else {
            return
        }

        let cellModel = viewModel.cellModels[sourceIndexPath.row]
        presenter.move(
            viewModel: cellModel,
            from: sourceIndexPath.row,
            to: destinationIndexPath.row
        )
    }
}

extension ManageAssetsViewController: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt _: IndexPath) {
        guard case let .loaded(viewModel) = state else {
            return
        }

//        presenter.didSelectViewModel(viewModel.accountViewModels[indexPath.row])
    }
}

extension ManageAssetsViewController: UITableViewDragDelegate {
    func tableView(_: UITableView, itemsForBeginning _: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard case let .loaded(viewModel) = state else {
            return []
        }

        let dragItem = UIDragItem(itemProvider: NSItemProvider())
        dragItem.localObject = viewModel.cellModels[indexPath.row]
        return [dragItem]
    }
}
