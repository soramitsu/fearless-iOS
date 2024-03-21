import UIKit
import SoraUI

final class AboutViewController: UIViewController, AdaptiveDesignable, ViewHolder {
    typealias RootViewType = AboutViewLayout

    // MARK: - Constants

    private enum Constants {
        static let rowHeight: CGFloat = 48.0
    }

    // MARK: - Private properties

    private var locale = Locale.current
    private var presenter: AboutPresenterProtocol

    // MARK: - State

    private var state: AboutViewState = .loading

    // MARK: - Constructors

    init(locale: Locale, presenter: AboutPresenterProtocol) {
        self.locale = locale
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cicle

    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView()
        presenter.didLoad(view: self)
        navigationController?.navigationBar.backgroundColor = .clear
    }

    override func loadView() {
        view = AboutViewLayout()
    }

    // MARK: UITableView

    private func configureTableView() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(AboutTableViewCell.self)
    }

    private func prepareCell(
        for tableView: UITableView,
        indexPath _: IndexPath,
        viewModel: AboutViewModel
    ) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellWithType(AboutTableViewCell.self) else {
            return UITableViewCell()
        }
        cell.bind(viewModel: viewModel)
        return cell
    }

    // MARK: - Private methods

    private func applyState(_ state: AboutViewState) {
        switch state {
        case .loading:
            break
        case .loaded:
            rootView.tableView.reloadData()
        }
    }
}

extension AboutViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int { 1 }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        guard case let .loaded(rows) = state else {
            return 0
        }
        return rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard case let .loaded(rows) = state else {
            return UITableViewCell()
        }
        return prepareCell(for: tableView, indexPath: indexPath, viewModel: rows[indexPath.row])
    }
}

extension AboutViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        Constants.rowHeight
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard case let .loaded(rows) = state else {
            return
        }

        if let url = rows[indexPath.row].url {
            presenter.activate(url: url)
        } else {
            presenter.activateWriteUs()
        }
    }
}

extension AboutViewController: AboutViewProtocol {
    func didReceive(locale: Locale) {
        self.locale = locale
        rootView.locale = locale
    }

    func didReceive(state: AboutViewState) {
        self.state = state
        applyState(state)
    }
}
