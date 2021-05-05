import UIKit
import SoraFoundation

final class ControllerAccountViewController: UIViewController, ViewHolder {
    typealias RootViewType = ControllerAccountViewLayout

    let presenter: ControllerAccountPresenterProtocol
    private var rows: [ControllerAccountRow] = []

    init(
        presenter: ControllerAccountPresenterProtocol,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? .autoupdatingCurrent
    }

    override func loadView() {
        view = ControllerAccountViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        applyLocalization()
        setupTable()
        presenter.setup()
    }

    func setupTable() {
        rootView.tableView.registerClassForCell(AccountInfoTableViewCell.self)
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
    }
}

extension ControllerAccountViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            title = R.string.localizable
                .stakingControllerAccountTitle(preferredLanguages: selectedLocale.rLanguages)
            rootView.actionButton.imageWithTitleView?.title = R.string.localizable
                .commonContinue(preferredLanguages: selectedLocale.rLanguages)
        }
    }
}

extension ControllerAccountViewController: ControllerAccountViewProtocol {
    func reload(with viewModel: LocalizableResource<ControllerAccountViewModel>) {
        let localizedViewModel = viewModel.value(for: selectedLocale)

        rows = localizedViewModel.rows
        rootView.tableView.reloadData()
    }
}

extension ControllerAccountViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        rows.count
    }

    func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch rows[indexPath.row] {
        case let .controller(viewModel):
            let cell = rootView.tableView.dequeueReusableCellWithType(AccountInfoTableViewCell.self)!
            cell.bind(model: viewModel)
            cell.delegate = self
            return cell
        case let .stash(viewModel):
            let cell = rootView.tableView.dequeueReusableCellWithType(AccountInfoTableViewCell.self)!
            cell.bind(model: viewModel)
            cell.delegate = self
            return cell
        default:
            return UITableViewCell()
        }
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch rows[indexPath.row] {
        case .stash, .controller:
            return 68.0
        default:
            return 48.0
        }
    }
}

extension ControllerAccountViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension ControllerAccountViewController: AccountInfoTableViewCellDelegate {
    func accountInfoCellDidReceiveAction(_: AccountInfoTableViewCell) {
        presenter.handleControllerAction()
    }
}
