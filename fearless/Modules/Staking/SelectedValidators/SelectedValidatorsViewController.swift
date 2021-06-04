import UIKit
import SoraFoundation

final class SelectedValidatorsViewController: UIViewController {
    var presenter: SelectedValidatorsPresenterProtocol!

    @IBOutlet private var tableView: UITableView!
    @IBOutlet var continueButton: TriangularedButton!

    private var viewModel: SelectedValidatorsViewModelProtocol?
    private weak var headerView: SelectedValidatorsHeaderView?

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? .autoupdatingCurrent
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupLocalization()
        presenter.setup()
    }

    private func setupTableView() {
        tableView.tableFooterView = UIView()

        tableView.register(R.nib.selectedValidatorCell)
        tableView.rowHeight = UIConstants.cellHeight

        if let headerView = R.nib.selectedValidatorsHeaderView.firstView(owner: nil) {
            headerView.heightAnchor.constraint(equalToConstant: UIConstants.tableHeaderHeight)
                .isActive = true
            tableView.tableHeaderView = headerView

            self.headerView = headerView
        }
    }

    private func updateHeaderView() {
        if let viewModel = viewModel {
            let languages = selectedLocale.rLanguages
            let title = viewModel
                .itemsCountString.value(for: selectedLocale)

            let details = R.string.localizable
                .stakingFilterTitleRewards(preferredLanguages: languages)

            headerView?.bind(
                title: title.uppercased(),
                details: details.uppercased()
            )
        }
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages
        title = R.string.localizable
            .stakingRecommendedSectionTitle(preferredLanguages: languages)

        continueButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: languages)
        continueButton.invalidateLayout()

        updateHeaderView()
    }

    @IBAction private func actionContinue() {
        presenter.proceed()
    }
}

extension SelectedValidatorsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModel?.itemViewModels.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView
            .dequeueReusableCell(
                withIdentifier: R.reuseIdentifier.selectedValidatorCellId,
                for: indexPath
            )!

        let items = viewModel?.itemViewModels ?? []
        cell.bind(viewModel: items[indexPath.row].value(for: selectedLocale))

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.selectedValidatorAt(index: indexPath.row)
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        100.0
    }

    func tableView(_: UITableView, viewForFooterInSection _: Int) -> UIView? {
        UIView()
    }
}

extension SelectedValidatorsViewController: SelectedValidatorsViewProtocol {
    func didReceive(viewModel: SelectedValidatorsViewModelProtocol) {
        self.viewModel = viewModel
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
