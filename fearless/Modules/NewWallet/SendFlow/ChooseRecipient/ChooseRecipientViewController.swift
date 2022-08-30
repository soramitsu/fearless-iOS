import UIKit

final class ChooseRecipientViewController: UIViewController, ViewHolder {
    typealias RootViewType = ChooseRecipientViewLayout

    let presenter: ChooseRecipientPresenterProtocol

    private var viewModel: ChooseRecipientViewModel?
    private var locale = Locale.current

    private lazy var searchActivityIndicatory: UIActivityIndicatorView = .init(style: .white)

    init(presenter: ChooseRecipientPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ChooseRecipientViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()

        configure()

        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    func configure() {
        rootView.searchView.textField.delegate = self

        rootView.tableView.registerClassForCell(SearchPeopleTableCell.self)

        rootView.tableView.tableFooterView = UIView()

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self

        rootView.navigationBar.backButton.addTarget(self, action: #selector(backButtonClicked), for: .touchUpInside)
    }

    @objc private func backButtonClicked() {
        presenter.didTapBackButton()
    }

    @objc private func scanButtonClicked() {
        presenter.didTapScanButton()
    }

    @objc private func historyButtonClicked() {
        presenter.didTapHistoryButton()
    }
}

extension ChooseRecipientViewController: ChooseRecipientViewProtocol {
    func didReceive(viewModel: ChooseRecipientViewModel) {
        rootView.tableView.isHidden = viewModel.results.isEmpty
    }

    func didReceive(locale: Locale) {
        self.locale = locale
        rootView.locale = locale
    }

    func didReceive(address: String) {
        rootView.searchView.textField.text = address
    }
}

extension ChooseRecipientViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        guard let viewModel = viewModel, !viewModel.results.isEmpty else {
            return 0
        }
        return 1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        guard let viewModel = viewModel, !viewModel.results.isEmpty else {
            return 0
        }
        return viewModel.results.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = viewModel else {
            return UITableViewCell()
        }
        guard let cell = tableView.dequeueReusableCellWithType(SearchPeopleTableCell.self) else {
            return UITableViewCell()
        }
        cell.bind(to: viewModel.results[indexPath.row])
        return cell
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let viewModel = viewModel else {
            return
        }
        presenter.didSelectViewModel(viewModel: viewModel.results[indexPath.row])
    }
}

extension ChooseRecipientViewController: UITextFieldDelegate {
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let text = textField.text as NSString? else {
            return true
        }

        let newString = text.replacingCharacters(in: range, with: string)

        presenter.searchTextDidChanged(newString)

        return true
    }

    func textFieldShouldClear(_: UITextField) -> Bool {
        presenter.searchTextDidChanged("")

        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        guard let text = textField.text else {
            return false
        }

        presenter.searchTextDidChanged(text)

        return false
    }
}

extension ChooseRecipientViewController: HiddableBarWhenPushed {}
