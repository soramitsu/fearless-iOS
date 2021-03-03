import UIKit
import SoraFoundation

final class SelectedValidatorsViewController: UIViewController {
    var presenter: SelectedValidatorsPresenterProtocol!

    @IBOutlet private var tableView: UITableView!

    private var viewModels: [LocalizableResource<SelectedValidatorViewModelProtocol>] = []
    private weak var headerView: SelectedValidatorsHeaderView?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupLocalization()
        presenter.setup()
    }

    private func setupTableView() {
        tableView.register(R.nib.selectedValidatorCell)
        tableView.rowHeight = UIConstants.cellHeight

        if let headerView = R.nib.selectedValidatorsHeaderView.firstView(owner: nil) {
            headerView.translatesAutoresizingMaskIntoConstraints = false
            headerView.heightAnchor.constraint(equalToConstant: UIConstants.tableHeaderHeight)
                .isActive = true
            tableView.tableHeaderView = headerView

            self.headerView = headerView
        }
    }

    private func updateHeaderView() {
        let languages = localizationManager?.selectedLocale.rLanguages
        let title = R.string.localizable
            .stakingSelectedValidatorsCount("\(viewModels.count)",
                                            "\(StakingConstants.maxTargets)",
                                            preferredLanguages: languages)
        headerView?.bind(title: title.uppercased())
    }

    private func setupLocalization() {
        let languages = localizationManager?.selectedLocale.rLanguages
        title = R.string.localizable
            .stakingSelectedValidatorsTitle(preferredLanguages: languages)

        updateHeaderView()
    }
}

extension SelectedValidatorsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView
            .dequeueReusableCell(withIdentifier: R.reuseIdentifier.selectedValidatorCellId,
                                 for: indexPath)!

        let locale = localizationManager?.selectedLocale ?? Locale.current
        cell.bind(viewModel: viewModels[indexPath.row].value(for: locale))

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension SelectedValidatorsViewController: SelectedValidatorsViewProtocol {
    func didReceive(viewModels: [LocalizableResource<SelectedValidatorViewModelProtocol>]) {
        self.viewModels = viewModels
        updateHeaderView()

        tableView.reloadData()
    }
}

extension SelectedValidatorsViewController {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
