import UIKit
import SoraUI
import CommonWallet

final class AboutViewController: UIViewController, AdaptiveDesignable, ViewHolder {
    typealias RootViewType = AboutViewLayout

    // MARK: - Constants

    private enum Constants {
        static let rowHeight: CGFloat = 48.0
    }

    // MARK: - Private properties

    private var locale = Locale.current
    private var presenter: AboutPresenterProtocol
    private var viewModel: [AboutViewModel]?

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
}

extension AboutViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int { 1 }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModel?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = viewModel?[indexPath.row] else { return UITableViewCell() }

        return prepareCell(for: tableView, indexPath: indexPath, viewModel: viewModel)
    }
}

extension AboutViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        Constants.rowHeight
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if let url = viewModel?[indexPath.row].url {
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

    func didReceive(viewModel: [AboutViewModel]) {
        self.viewModel = viewModel
        rootView.tableView.reloadData()
    }
}
