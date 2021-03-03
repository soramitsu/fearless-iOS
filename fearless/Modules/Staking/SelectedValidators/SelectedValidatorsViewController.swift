import UIKit
import SoraFoundation

final class SelectedValidatorsViewController: UIViewController {
    var presenter: SelectedValidatorsPresenterProtocol!

    @IBOutlet private var tableView: UITableView!

    private var viewModels: [LocalizableResource<SelectedValidatorViewModelProtocol>] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupLocalization()
        presenter.setup()
    }

    private func setupTableView() {
        tableView.register(R.nib.selectedValidatorCell)
        tableView.rowHeight = 48
    }

    private func setupLocalization() {
        let languages = localizationManager?.selectedLocale.rLanguages
        title = R.string.localizable
            .stakingRecommendedValidatorsTitle(preferredLanguages: languages)
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

    }
}

extension SelectedValidatorsViewController: SelectedValidatorsViewProtocol {
    func didReceive(viewModels: [LocalizableResource<SelectedValidatorViewModelProtocol>]) {
        self.viewModels = viewModels
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
