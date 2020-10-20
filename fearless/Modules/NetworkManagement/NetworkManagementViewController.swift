import UIKit
import SoraUI
import SoraFoundation

final class NetworkManagementViewController: UIViewController {
    private struct Constants {
        static let cellHeight: CGFloat = 48.0
        static let headerHeight: CGFloat = 33.0
        static let headerId = "networkHeaderId"
        static let bottomContentHeight: CGFloat = 48
    }

    enum Section: Int {
        case defaultConnections
        case customConnections
    }

    var presenter: NetworkManagementPresenterProtocol!

    @IBOutlet private var tableView: UITableView!

    @IBOutlet private var bottomBarHeight: NSLayoutConstraint!

    @IBOutlet private var addActionControl: IconCellControlView!

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupNavigationItem()
        setupLocalization()

        presenter.setup()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        bottomBarHeight.constant = Constants.bottomContentHeight + view.safeAreaInsets.bottom
    }

    private func setupNavigationItem() {
        let rightBarButtonItem = UIBarButtonItem(title: "",
                                                 style: .plain,
                                                 target: self,
                                                 action: #selector(actionEdit))

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorWhite()!,
            .font: UIFont.h5Title
        ]

        rightBarButtonItem.setTitleTextAttributes(attributes, for: .normal)
        rightBarButtonItem.setTitleTextAttributes(attributes, for: .highlighted)

        navigationItem.rightBarButtonItem = rightBarButtonItem
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale

        title = R.string.localizable
            .connectionManagementTitle(preferredLanguages: locale?.rLanguages)

        addActionControl.imageWithTitleView?.title = R.string.localizable
            .connectionsAddConnection(preferredLanguages: locale?.rLanguages)

        updateRightItem()
    }

    private func updateRightItem() {
        let locale = localizationManager?.selectedLocale

        if tableView.isEditing {
            navigationItem.rightBarButtonItem?.title = R.string.localizable
                .commonDone(preferredLanguages: locale?.rLanguages)
        } else {
            navigationItem.rightBarButtonItem?.title = R.string.localizable
            .commonEdit(preferredLanguages: locale?.rLanguages)
        }
    }

    private func setupTableView() {
        tableView.tableFooterView = UIView()

        tableView.register(R.nib.connectionTableViewCell)
        tableView.register(UINib(resource: R.nib.iconTitleHeaderView),
                           forHeaderFooterViewReuseIdentifier: Constants.headerId)
    }

    @objc func actionEdit() {
        tableView.setEditing(!tableView.isEditing, animated: true)
        updateRightItem()

        for cell in tableView.visibleCells where
            tableView.indexPath(for: cell)?.section == Section.customConnections.rawValue {
            if let accountCell = cell as? ConnectionTableViewCell {
                accountCell.setReordering(tableView.isEditing, animated: true)
            }
        }
    }

    @IBAction func actionAdd() {
        presenter.activateConnectionAdd()
    }
}

extension NetworkManagementViewController: NetworkManagementViewProtocol {
    func reload() {
        tableView.reloadData()
    }
}

// swiftlint:disable force_cast
extension NetworkManagementViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return presenter.numberOfCustomConnections() > 0 ? 2 : 1
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: Constants.headerId) as! IconTitleHeaderView

        let section = Section(rawValue: section)!

        let locale = localizationManager?.selectedLocale
        let title: String

        switch section {
        case .defaultConnections:
            title = R.string.localizable
                .connectionManagementDefaultTitle(preferredLanguages: locale?.rLanguages)
        case .customConnections:
            title = R.string.localizable
                .connectionManagementCustomTitle(preferredLanguages: locale?.rLanguages)
        }

        view.bind(title: title.uppercased(), icon: nil)

        return view
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = Section(rawValue: section)!

        switch section {
        case .defaultConnections:
            return presenter.numberOfDefaultConnections()
        case .customConnections:
            return presenter.numberOfCustomConnections()
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.connectionCellId,
                                                 for: indexPath)!

        cell.delegate = self

        let section = Section(rawValue: indexPath.section)!

        let viewModel: ManagedConnectionViewModel

        switch section {
        case .defaultConnections:
            viewModel = presenter.defaultConnection(at: indexPath.row)
            cell.setReordering(false, animated: false)
        case .customConnections:
            viewModel = presenter.customConnection(at: indexPath.row)
            cell.setReordering(tableView.isEditing, animated: false)
        }

        cell.bind(viewModel: viewModel)

        return cell
    }
}
// swiftlint:enable force_cast

extension NetworkManagementViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        Constants.cellHeight
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        Constants.headerHeight
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let section = Section(rawValue: indexPath.section) else {
            return
        }

        switch section {
        case .defaultConnections:
            presenter.selectDefaultItem(at: indexPath.row)
        case .customConnections:
            presenter.selectCustomItem(at: indexPath.row)
        }
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == Section.customConnections.rawValue
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath,
                   to destinationIndexPath: IndexPath) {
        presenter.moveCustomItem(at: sourceIndexPath.row, to: destinationIndexPath.row)
    }

    func tableView(_ tableView: UITableView,
                   targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
                   toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        if proposedDestinationIndexPath.section < sourceIndexPath.section {
            return IndexPath(row: 0, section: sourceIndexPath.section)
        } else if proposedDestinationIndexPath.section > sourceIndexPath.section {
            let count = tableView.numberOfRows(inSection: sourceIndexPath.section)
            return IndexPath(row: count - 1, section: sourceIndexPath.section)
        } else {
            return proposedDestinationIndexPath
        }
    }

    func tableView(_ tableView: UITableView,
                   editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        guard let section = Section(rawValue: indexPath.section) else {
            return .none
        }

        switch section {
        case .defaultConnections:
            return .none
        case .customConnections:
            return !presenter.customConnection(at: indexPath.row).isSelected ? .delete : .none
        }
    }

    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        let numberOfRows = tableView.numberOfRows(inSection: indexPath.section)

        presenter.removeCustomItem(at: indexPath.row)

        if numberOfRows == 1 {
            tableView.deleteSections([indexPath.section], with: .automatic)
        } else {
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
}

extension NetworkManagementViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            tableView.reloadData()
        }
    }
}

extension NetworkManagementViewController: ConnectionTableViewCellDelegate {
    func didSelectInfo(_ cell: ConnectionTableViewCell) {
        guard
            let indexPath = tableView.indexPath(for: cell),
            let section = Section(rawValue: indexPath.section) else {
            return
        }

        switch section {
        case .defaultConnections:
            presenter.activateDefaultConnectionDetails(at: indexPath.row)
        case .customConnections:
            presenter.activateCustomConnectionDetails(at: indexPath.row)
        }
    }
}
