import UIKit
import SoraFoundation

protocol FeatureToggleListViewOutput: AnyObject {
    func didLoad(view: FeatureToggleListViewInput)
    func didSwitch(index: Int)
}

final class FeatureToggleListViewController: UIViewController, ViewHolder {
    typealias RootViewType = FeatureToggleListViewLayout

    // MARK: Private properties

    private let output: FeatureToggleListViewOutput

    private var viewModels: [SelectableViewModel<TitleWithSubtitleViewModel>] = []

    // MARK: - Constructor

    init(
        output: FeatureToggleListViewOutput,
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
        view = FeatureToggleListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        title = "Toggle list"
        setupTableView()
    }

    // MARK: - Private methods

    private func setupTableView() {
        rootView.tableView.registerClassForCell(TitleSubtitleSwitchTableViewCell.self)
        rootView.tableView.dataSource = self
        rootView.tableView.rowHeight = 44
    }
}

// MARK: - FeatureToggleListViewInput

extension FeatureToggleListViewController: FeatureToggleListViewInput {
    func didReceive(viewModels: [SelectableViewModel<TitleWithSubtitleViewModel>]) {
        self.viewModels = viewModels
        rootView.tableView.reloadData()
    }
}

// MARK: - Localizable

extension FeatureToggleListViewController: Localizable {
    func applyLocalization() {}
}

// MARK: - UITableViewDataSource

extension FeatureToggleListViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = viewModels[safe: indexPath.row] else { return UITableViewCell() }

        let cell = tableView.dequeueReusableCellWithType(TitleSubtitleSwitchTableViewCell.self)!
        cell.delegate = self
        cell.bind(viewModel: viewModel)

        return cell
    }
}

extension FeatureToggleListViewController: SwitchTableViewCellDelegate {
    func didToggle(cell: SwitchTableViewCell) {
        guard let indexPath = rootView.tableView.indexPath(for: cell) else {
            return
        }
        output.didSwitch(index: indexPath.row)
    }
}
