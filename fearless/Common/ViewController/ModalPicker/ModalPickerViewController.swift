import UIKit
import SoraUI
import SoraFoundation

protocol ModalPickerViewControllerDelegate: class {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?)
    func modalPickerDidCancel(context: AnyObject?)
}

class ModalPickerViewController<C: UITableViewCell & ModalPickerCellProtocol, T>: UIViewController,
    ModalViewProtocol, UITableViewDelegate, UITableViewDataSource where T == C.Model {

    @IBOutlet private var headerLabel: UILabel!
    @IBOutlet private var headerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private var tableView: UITableView!

    var localizedTitle: LocalizableResource<String>?

    var cellNib: UINib?
    var cellHeight: CGFloat = 55.0
    var footerHeight: CGFloat = 24.0
    var headerHeight: CGFloat = 40.0
    var cellIdentifier: String = "modalPickerCellId"
    var selectedIndex: Int = 0

    var viewModels: [LocalizableResource<T>] = []

    weak var delegate: ModalPickerViewControllerDelegate?
    weak var presenter: ModalPresenterProtocol?

    var context: AnyObject?

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        setupLocalization()
    }

    private func configure() {
        if let cellNib = cellNib {
            tableView.register(cellNib, forCellReuseIdentifier: cellIdentifier)
        } else {
            tableView.register(C.self, forCellReuseIdentifier: cellIdentifier)
        }

        headerHeightConstraint.constant = headerHeight
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        headerLabel.text = localizedTitle?.value(for: locale)
    }

    // MARK: Table View Delegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.row != selectedIndex {
            if var oldCell = tableView.cellForRow(at: IndexPath(row: selectedIndex, section: 0)) as? C {
                oldCell.checkmarked = false
            }

            if var newCell = tableView.cellForRow(at: indexPath) as? C {
                newCell.checkmarked = true
            }

            selectedIndex = indexPath.row

            delegate?.modalPickerDidSelectModelAtIndex(indexPath.row, context: context)
            presenter?.hide(view: self, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return cellHeight
    }

    // MARK: Table View Data Source

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModels.count
    }

    //swiftlint:disable force_cast
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! C

        let locale = localizationManager?.selectedLocale ?? Locale.current

        cell.bind(model: viewModels[indexPath.row].value(for: locale))
        cell.checkmarked = (selectedIndex == indexPath.row)

        return cell
    }
    //swiftlint:enable force_cast
}

extension ModalPickerViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            tableView.reloadData()
        }
    }
}

extension ModalPickerViewController: ModalPresenterDelegate {
    func presenterDidHide(_ presenter: ModalPresenterProtocol) {
        delegate?.modalPickerDidCancel(context: context)
    }
}
