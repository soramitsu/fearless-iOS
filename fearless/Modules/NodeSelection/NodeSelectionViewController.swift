import UIKit

final class NodeSelectionViewController: UIViewController, ViewHolder {
    enum Constants {
        static let tableSectionHeaderHeight: CGFloat = 30
    }

    typealias RootViewType = NodeSelectionViewLayout

    let presenter: NodeSelectionPresenterProtocol

    var state: NodeSelectionViewState = .loading
    var tableState: NodeSelectionTableState = .normal
    var locale = Locale.current

    var loadableContentView: UIView {
        rootView.tableView
    }

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

        rootView.tableView.contentInsetAdjustmentBehavior = .never
        rootView.tableView.contentInset = .zero

        rootView.tableView.registerClassForCell(NodeSelectionTableCell.self)
        rootView.tableView.tableFooterView = UIView()
        rootView.tableView.tableHeaderView = UIView()

        if #available(iOS 15.0, *) {
            rootView.tableView.sectionHeaderTopPadding = 0
        }

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self

        rootView.switchView.addTarget(self, action: #selector(automaticNodeSwitchChangedValue(_:)), for: .valueChanged)
        rootView.navigationBar.backButton.addTarget(self, action: #selector(closeButtonClicked), for: .touchUpInside)
        rootView.editButton.addTarget(self, action: #selector(editButtonClicked), for: .touchUpInside)
        rootView.addNodeButton.addTarget(self, action: #selector(addNodeButtonClicked), for: .touchUpInside)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        tableState = .normal
    }

    func applyState() {
        switch state {
        case .loading:
            break
        case let .loaded(viewModel):
            rootView.editButton.isHidden = viewModel.sections.count < 2
            rootView.bind(to: viewModel)

            rootView.tableView.reloadData()
            didStopLoading()
        }
    }

    @objc private func automaticNodeSwitchChangedValue(_ sender: UISwitch) {
        didStartLoading()
        presenter.didChangeValueForAutomaticNodeSwitch(isOn: sender.isOn)
    }

    @objc private func editButtonClicked() {
        tableState = tableState.reversed
        rootView.tableView.reloadData()

        let editButtonTitle = tableState == .normal
            ? R.string.localizable.commonEdit(preferredLanguages: locale.rLanguages)
            : R.string.localizable.commonDone(preferredLanguages: locale.rLanguages)
        rootView.editButton.setTitle(editButtonTitle, for: .normal)
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
        self.locale = locale
        rootView.locale = locale
    }
}

extension NodeSelectionViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard case let .loaded(viewModel) = state else {
            return nil
        }

        let sectionHeaderView = TableSectionTitleView()
        sectionHeaderView.titleLabel.text = viewModel.sections[section].title

        return sectionHeaderView
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard case let .loaded(viewModel) = state else {
            return 0
        }

        return !viewModel.sections[section].viewModels.isEmpty ? Constants.tableSectionHeaderHeight : .leastNormalMagnitude
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        .leastNormalMagnitude
    }

    func numberOfSections(in _: UITableView) -> Int {
        guard case let .loaded(viewModel) = state else {
            return 0
        }

        return viewModel.sections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard case let .loaded(viewModel) = state else {
            return 0
        }

        return viewModel.sections[section].viewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard case let .loaded(viewModel) = state else {
            return UITableViewCell()
        }

        guard let cell = tableView.dequeueReusableCellWithType(NodeSelectionTableCell.self)
        else {
            return UITableViewCell()
        }

        let cellViewModel = viewModel.sections[indexPath.section].viewModels[indexPath.row]
        cell.bind(to: cellViewModel, tableState: tableState)

        return cell
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard case let .loaded(viewModel) = state else {
            return
        }

        let cellViewModel = viewModel.sections[indexPath.section].viewModels[indexPath.row]

        didStartLoading()
        presenter.didSelectNode(cellViewModel.node)
    }
}
