import UIKit
import SoraFoundation

final class SelectValidatorsViewController: UIViewController, ViewHolder {
    typealias RootViewType = SelectValidatorsViewLayout

    let presenter: SelectValidatorsPresenterProtocol

    private var cellViewModels: [SelectValidatorsCellViewModel] = []

    init(
        presenter: SelectValidatorsPresenterProtocol,
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
        view = SelectValidatorsViewLayout()
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
        rootView.tableView.registerClassForCell(SelectValidatorsCell.self)
    }

    @objc
    private func handleValidatorInfo() {
        presenter.didSelectValidator(at: 0)
    }
}

extension SelectValidatorsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            title = "Select validators"
        }
    }
}

extension SelectValidatorsViewController: SelectValidatorsViewProtocol {
    func reload(with viewModel: [SelectValidatorsCellViewModel]) {
        cellViewModels = viewModel
        rootView.tableView.reloadData()
    }
}

extension SelectValidatorsViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        cellViewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(SelectValidatorsCell.self)!
        let viewModel = cellViewModels[indexPath.row]
        cell.bind(viewModel: viewModel)
        cell.infoButton.addTarget(self, action: #selector(handleValidatorInfo), for: .touchUpInside)
        return cell
    }
}
