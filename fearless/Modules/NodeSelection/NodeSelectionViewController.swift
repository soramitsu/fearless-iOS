import UIKit

final class NodeSelectionViewController: UIViewController, ViewHolder {
    typealias RootViewType = NodeSelectionViewLayout

    let presenter: NodeSelectionPresenterProtocol

    var state: NodeSelectionViewState = .loading
    var tableState: NodeSelectionTableState = .normal

    init(presenter: NodeSelectionPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NodeSelectionViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()

        rootView.tableView.registerClassForCell(NodeSelectionTableCell.self)

        rootView.tableView.tableFooterView = UIView()

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self

        rootView.switchView.addTarget(self, action: #selector(automaticNodeSwitchChangedValue(_:)), for: .valueChanged)
        rootView.navigationBar.backButton.addTarget(self, action: #selector(closeButtonClicked), for: .touchUpInside)
        rootView.editButton.addTarget(self, action: #selector(editButtonClicked), for: .touchUpInside)
        rootView.addNodeButton.addTarget(self, action: #selector(addNodeButtonClicked), for: .touchUpInside)
    }

    func applyState() {
        switch state {
        case .loading:
            break
        case let .loaded(viewModel):
            rootView.bind(to: viewModel)

            rootView.tableView.reloadData()
        }
    }

    @objc private func automaticNodeSwitchChangedValue(_ sender: UISwitch) {
        presenter.didChangeValueForAutomaticNodeSwitch(isOn: sender.isOn)
    }

    @objc private func editButtonClicked() {
        tableState = tableState.reversed
    }

    @objc private func closeButtonClicked() {
        presenter.didTapCloseButton()
    }

    @objc private func addNodeButtonClicked() {
        presenter.didTapAddNodeButton()
    }
}

extension NodeSelectionViewController: NodeSelectionViewProtocol {
    func didReceive(state: NodeSelectionViewState) {
        self.state = state
        applyState()
    }

    func didReceive(locale: Locale) {
        rootView.locale = locale
    }
}

extension NodeSelectionViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        guard case .loaded = state else {
            return 0
        }

        return 1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        guard case let .loaded(viewModel) = state else {
            return 0
        }

        return viewModel.viewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard case let .loaded(viewModel) = state else {
            return UITableViewCell()
        }

        guard let cell = tableView.dequeueReusableCellWithType(NodeSelectionTableCell.self)
        else {
            return UITableViewCell()
        }

        cell.bind(to: viewModel.viewModels[indexPath.row])
        return cell
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard case let .loaded(viewModel) = state else {
            return
        }

        presenter.didSelectNode(viewModel.viewModels[indexPath.row].node)
    }
}
