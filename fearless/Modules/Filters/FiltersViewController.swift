import UIKit

final class FiltersViewController: UIViewController, ViewHolder {
    typealias RootViewType = FiltersViewLayout

    let presenter: FiltersPresenterProtocol

    var state: FiltersViewState = .empty

    private let screenTitle: String?

    init(
        screenTitle: String?,
        presenter: FiltersPresenterProtocol
    ) {
        self.screenTitle = screenTitle
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = FiltersViewLayout(screenTitle: screenTitle)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()

        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.registerClassForCell(SwitchFilterTableCell.self)
        rootView.tableView.registerClassForCell(SortTableCell.self)
        rootView.tableView.separatorStyle = .none

        rootView.resetButton.addTarget(self, action: #selector(resetButtonClicked), for: .touchUpInside)
        rootView.applyButton.addTarget(self, action: #selector(applyButtonClicked), for: .touchUpInside)
        rootView.navigationBar.backButton.addTarget(self, action: #selector(closeButtonClicked), for: .touchUpInside)
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

            rootView.bind(viewModel: viewModel)
        }
    }

    @objc func resetButtonClicked() {
        presenter.didTapResetButton()
    }

    @objc func applyButtonClicked() {
        presenter.didTapApplyButton()
    }

    @objc func closeButtonClicked() {
        presenter.didTapCloseButton()
    }
}

extension FiltersViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard case let .loaded(viewModel) = state else {
            return nil
        }

        let section = viewModel.sections[section]
        guard let sectionTitle = section.title else {
            return nil
        }

        let view = FilterSectionHeaderView()
        view.titleLabel.text = sectionTitle
        return view
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard case let .loaded(viewModel) = state else {
            return 0
        }

        let section = viewModel.sections[section]

        return section.title == nil ? 0 : 40
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

        if let sortCellViewModel = cellModel as? SortFilterCellViewModel,
           let cell = tableView.dequeueReusableCellWithType(SortTableCell.self) {
            cell.bind(to: sortCellViewModel)
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

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard case let .loaded(viewModel) = state else {
            return
        }
        let sectionViewModel = viewModel.sections[indexPath.section]
        let cellModel = sectionViewModel.items[indexPath.row]

        if let sortCellViewModel = cellModel as? SortFilterCellViewModel {
            presenter.didSelectSort(viewModel: sortCellViewModel)
        }
    }
}

extension FiltersViewController: FiltersViewProtocol {
    func didReceive(state: FiltersViewState) {
        self.state = state

        applyState()
    }

    func didReceive(locale: Locale) {
        rootView.locale = locale
    }

    func didReceive(applyEnabled: Bool) {
        rootView.applyButton.set(enabled: applyEnabled)
    }
}
