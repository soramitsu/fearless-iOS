import UIKit
import SoraUI
import SoraFoundation

protocol ModalPickerViewControllerDelegate: class {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?)
    func modalPickerDidCancel(context: AnyObject?)
    func modalPickerDidSelectAction(context: AnyObject?)
}

extension ModalPickerViewControllerDelegate {
    func modalPickerDidCancel(context: AnyObject?) {}
    func modalPickerDidSelectAction(context: AnyObject?) {}
}

enum ModalPickerViewAction {
    case none
    case add
}

class ModalPickerViewController<C: UITableViewCell & ModalPickerCellProtocol, T>: UIViewController,
    ModalViewProtocol, UITableViewDelegate, UITableViewDataSource where T == C.Model {

    @IBOutlet private var headerView: ImageWithTitleView!
    @IBOutlet private var headerBackgroundView: BorderedContainerView!
    @IBOutlet private var headerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private var tableView: UITableView!

    var localizedTitle: LocalizableResource<String>?
    var icon: UIImage?
    var actionType: ModalPickerViewAction = .none

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

        if let icon = icon {
            headerView.iconImage = icon
        } else {
            headerView.spacingBetweenLabelAndIcon = 0
        }

        switch actionType {
        case .add:
            configureAddAction()
        default:
            break
        }
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        headerView.title = localizedTitle?.value(for: locale)
    }

    private func configureAddAction() {
        let addButton = RoundedButton()
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.roundedBackgroundView?.shadowOpacity = 0.0
        addButton.roundedBackgroundView?.fillColor = .clear
        addButton.roundedBackgroundView?.highlightedFillColor = .clear
        addButton.changesContentOpacityWhenHighlighted = true
        addButton.contentInsets = UIEdgeInsets(top: 20.0, left: 20.0, bottom: 20.0, right: 20.0)
        addButton.imageWithTitleView?.iconImage = R.image.iconSmallAdd()

        headerBackgroundView.addSubview(addButton)

        addButton.trailingAnchor.constraint(equalTo: headerBackgroundView.trailingAnchor).isActive = true
        addButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor).isActive = true

        addButton.addTarget(self, action: #selector(handleAction), for: .touchUpInside)
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

    @objc private func handleAction() {
        delegate?.modalPickerDidSelectAction(context: context)
        presenter?.hide(view: self, animated: true)
    }
}

extension ModalPickerViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            headerView.setNeedsLayout()
            tableView.reloadData()
        }
    }
}

extension ModalPickerViewController: ModalPresenterDelegate {
    func presenterDidHide(_ presenter: ModalPresenterProtocol) {
        delegate?.modalPickerDidCancel(context: context)
    }
}
