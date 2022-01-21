import UIKit

final class WalletDetailsViewController: UIViewController, ViewHolder {
    enum Constants {
        static let cellHeight: CGFloat = 48
    }

    typealias RootViewType = WalletDetailsViewLayout

    let output: WalletDetailsViewOutputProtocol
    private var chainViewModels: [WalletDetailsCellViewModel]?

    init(output: WalletDetailsViewOutputProtocol) {
        self.output = output
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = WalletDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()

        output.didLoad(ui: self)
    }

    @objc private func closeButtonClicked() {
        output.didTapCloseButton()
    }
}

extension WalletDetailsViewController: WalletDetailsViewProtocol {
    func bind(to viewModel: WalletDetailsViewModel) {
        chainViewModels = viewModel.chainViewModels
        rootView.tableView.refreshControl?.endRefreshing()
        rootView.tableView.reloadData()
        rootView.bind(to: viewModel)
    }
}

private extension WalletDetailsViewController {
    func configure() {
        rootView.tableView.registerClassForCell(WalletDetailsTableCell.self)

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self

        rootView.navigationBar.backButton.addTarget(
            self,
            action: #selector(closeButtonClicked),
            for: .touchUpInside
        )
    }
}

extension WalletDetailsViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        guard chainViewModels != nil else {
            return 0
        }
        return 1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        guard let viewModels = chainViewModels else {
            return 0
        }
        return viewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard
            let viewModels = chainViewModels,
            let cell = tableView.dequeueReusableCellWithType(WalletDetailsTableCell.self) else {
            return UITableViewCell()
        }

        cell.bind(to: viewModels[indexPath.row])
        return cell
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        Constants.cellHeight
    }
}

extension WalletDetailsViewController: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt _: IndexPath) {}
}

extension WalletDetailsViewController: HiddableBarWhenPushed {}
