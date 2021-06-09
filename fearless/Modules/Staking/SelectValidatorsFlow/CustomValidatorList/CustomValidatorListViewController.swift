import UIKit
import SoraFoundation

final class CustomValidatorListViewController: UIViewController, ViewHolder {
    typealias RootViewType = CustomValidatorListViewLayout

    let presenter: CustomValidatorListPresenterProtocol

    private var cellViewModels: [CustomValidatorCellViewModel] = []

    init(
        presenter: CustomValidatorListPresenterProtocol,
        localizationManager: LocalizationManagerProtocol? = nil
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CustomValidatorListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        applyLocalization()
        setupTable()
        presenter.setup()
    }

    private func setupTable() {
        rootView.tableView.dataSource = self
        // rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(CustomValidatorCell.self)
    }

    @objc
    private func handleValidatorInfo() {
        presenter.didSelectValidator(at: 0)
    }
}

extension CustomValidatorListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            title = "Select validators"
        }
    }
}

extension CustomValidatorListViewController: CustomValidatorListViewProtocol {
    func reload(with viewModel: [CustomValidatorCellViewModel]) {
        cellViewModels = viewModel
        rootView.tableView.reloadData()
    }
}

extension CustomValidatorListViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        cellViewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(CustomValidatorCell.self)!
        let viewModel = cellViewModels[indexPath.row]
        cell.bind(viewModel: viewModel)
        cell.infoButton.addTarget(self, action: #selector(handleValidatorInfo), for: .touchUpInside)
        return cell
    }
}
