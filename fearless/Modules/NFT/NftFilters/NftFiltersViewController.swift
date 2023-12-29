import UIKit

final class NftFiltersViewController: UIViewController, ViewHolder {
    typealias RootViewType = NftFiltersViewLayout

    let presenter: NftFiltersPresenterProtocol

    var state: FiltersViewState = .empty

    init(presenter: NftFiltersPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NftFiltersViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()

        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.registerClassForCell(SwitchFilterTableCell.self)
        rootView.tableView.separatorStyle = .none

        rootView.closeButton.addTarget(self, action: #selector(closeButtonClicked), for: .touchUpInside)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        presenter.willDisappear()
    }

    func applyState() {
        switch state {
        case .loading:
            rootView.tableView.isHidden = true
        case .empty:
            rootView.tableView.isHidden = true

        case .loaded:
            rootView.tableView.isHidden = false
            rootView.tableView.reloadData()
        }
    }

    @objc func closeButtonClicked() {
        presenter.didTapCloseButton()
    }
}

extension NftFiltersViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard case let .loaded(viewModel) = state else {
            return nil
        }

        let section = viewModel.sections[section]

        let view = FilterSectionHeaderView()
        view.titleLabel.text = section.title
        return view
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard case let .loaded(viewModel) = state else {
            return 0
        }

        let vmSection = viewModel.sections[section]

        guard let title = vmSection.title else {
            return 0
        }
        return title.isEmpty ? 0 : 40
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard case let .loaded(viewModel) = state else {
            return 0
        }

        let section = viewModel.sections[section]

        return section.items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard case let .loaded(viewModel) = state else {
            return UITableViewCell()
        }

        let sectionViewModel = viewModel.sections[indexPath.section]

        let cellModel = sectionViewModel.items[indexPath.row]

        if let switchingFilterCellModel = cellModel as? SwitchFilterTableCellViewModel,
           let cell = tableView.dequeueReusableCellWithType(SwitchFilterTableCell.self) {
            cell.bind(to: switchingFilterCellModel)
            return cell
        }

        return UITableViewCell()
    }

    func numberOfSections(in _: UITableView) -> Int {
        guard case let .loaded(viewModel) = state else {
            return 0
        }

        return viewModel.sections.count
    }
}

extension NftFiltersViewController: NftFiltersViewProtocol {
    func didReceive(state: FiltersViewState) {
        self.state = state

        applyState()
    }

    func didReceive(locale: Locale) {
        rootView.locale = locale
    }
}
