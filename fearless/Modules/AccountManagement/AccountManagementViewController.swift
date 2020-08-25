import UIKit
import SoraFoundation

final class AccountManagementViewController: UIViewController {
    private struct Constants {
        static let cellHeight: CGFloat = 48.0
        static let headerHeight: CGFloat = 33.0
        static let headerId = "accountHeaderId"
    }

    var presenter: AccountManagementPresenterProtocol!

    @IBOutlet private var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupNavigationItem()
        setupLocalization()

        presenter.setup()
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

        navigationItem.rightBarButtonItem = rightBarButtonItem
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale

        title = R.string.localizable.profileAccountsTitle(preferredLanguages: locale?.rLanguages)

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
        tableView.register(R.nib.accountTableViewCell)
        tableView.register(UINib(resource: R.nib.iconTitleHeaderView),
                           forHeaderFooterViewReuseIdentifier: Constants.headerId)
    }

    @objc func actionEdit() {
        tableView.setEditing(!tableView.isEditing, animated: true)
        updateRightItem()
    }
}

// swiftlint:disable force_cast
extension AccountManagementViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        presenter.numberOfSections()
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: Constants.headerId) as! IconTitleHeaderView

        let section = presenter.section(at: section)
        view.bind(title: section.title, icon: section.icon)

        return view
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        presenter.section(at: section).items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.accountCellId,
                                                 for: indexPath)!

        let item = presenter.section(at: indexPath.section).items[indexPath.row]
        cell.bind(viewModel: item)

        return cell
    }
}
// swiftlint:enable force_cast

extension AccountManagementViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        Constants.cellHeight
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        Constants.headerHeight
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        presenter.selectItem(at: indexPath.row, in: indexPath.section)
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        !presenter.section(at: indexPath.section).items[indexPath.row].isSelected
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        true
    }

    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        false
    }
}

extension AccountManagementViewController: AccountManagementViewProtocol {
    func reload() {
        tableView.reloadData()
    }
}

extension AccountManagementViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
