import UIKit
import SoraFoundation

final class AnalyticsValidatorsViewController: UIViewController, ViewHolder {
    typealias RootViewType = AnalyticsValidatorsView

    let presenter: AnalyticsValidatorsPresenterProtocol

    private var state: AnalyticsViewState<AnalyticsValidatorsViewModel>?

    init(presenter: AnalyticsValidatorsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AnalyticsValidatorsView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTable()
        presenter.setup()
    }

    private func setupTable() {
        rootView.tableView.registerClassForCell(AnalyticsValidatorsCell.self)
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
    }
}

extension AnalyticsValidatorsViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        guard case let .loaded(viewModel) = state else { return 0 }
        return viewModel.validators.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(AnalyticsValidatorsCell.self, forIndexPath: indexPath)
        guard case let .loaded(viewModel) = state else {
            return cell
        }
        let cellViewModel = viewModel.validators[indexPath.row]
        cell.bind(viewModel: cellViewModel)
        return cell
    }
}

extension AnalyticsValidatorsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard case let .loaded(viewModel) = state else {
            return
        }
    }
}

extension AnalyticsValidatorsViewController: AnalyticsValidatorsViewProtocol {
    var localizedTitle: LocalizableResource<String> {
        LocalizableResource { _ in
            "Validators"
        }
    }

    func reload(viewState: AnalyticsViewState<AnalyticsValidatorsViewModel>) {
        state = viewState

        switch viewState {
        case let .loading(isLoading):
            rootView.tableView.isHidden = true
            if !isLoading {
                rootView.tableView.refreshControl?.endRefreshing()
            }
        case let .loaded(viewModel):
            if !viewModel.validators.isEmpty {
                rootView.tableView.isHidden = false
                rootView.tableView.reloadData()
            }
        case let .error(error):
            rootView.tableView.isHidden = true
        }
    }
}
