import UIKit

final class FiltersViewController: UIViewController, ViewHolder {
    typealias RootViewType = FiltersViewLayout

    let presenter: FiltersPresenterProtocol

    var state: FiltersViewState = .empty

    init(presenter: FiltersPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = FiltersViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()

        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.registerClassForCell(SwitchFilterTableCell.self)
        rootView.tableView.separatorStyle = .none

        rootView.resetButton.addTarget(self, action: #selector(resetButtonClicked), for: .touchUpInside)
        rootView.applyButton.addTarget(self, action: #selector(applyButtonClicked), for: .touchUpInside)
    }

    func applyState() {
        switch state {
        case .loading:
            rootView.tableView.isHidden = true
        case .empty:
            rootView.tableView.isHidden = true

        case let .loaded(viewModel):
            rootView.tableView.isHidden = false
            rootView.tableView.reloadData()
        }
    }

    @objc func resetButtonClicked() {
        presenter.didTapResetButton()
    }

    @objc func applyButtonClicked() {
        presenter.didTapApplyButton()
    }
}

extension FiltersViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        guard case let .loaded(viewModel) = state else {
            return 0
        }

        return viewModel.cellModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard case let .loaded(viewModel) = state else {
            return UITableViewCell()
        }

        let cellModel = viewModel.cellModels[indexPath.row]

        if let switchingFilterCellModel = cellModel as? SwitchFilterTableCellViewModel,
           let cell = tableView.dequeueReusableCellWithType(SwitchFilterTableCell.self) {
            cell.bind(to: switchingFilterCellModel)
            return cell
        }

        return UITableViewCell()
    }

    func numberOfSections(in _: UITableView) -> Int {
        1
    }
}

extension FiltersViewController: FiltersViewProtocol {
    func didReceive(state: FiltersViewState) {
        self.state = state
    }
}
