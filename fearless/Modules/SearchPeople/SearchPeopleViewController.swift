import UIKit

final class SearchPeopleViewController: UIViewController, ViewHolder {
    typealias RootViewType = SearchPeopleViewLayout

    let presenter: SearchPeoplePresenterProtocol

    private var state: SearchPeopleViewState = .empty

    private lazy var searchActivityIndicatory: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .white)
        return activityIndicator
    }()

    init(presenter: SearchPeoplePresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SearchPeopleViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()

        configure()
    }

    func configure() {
        rootView.searchField.delegate = self

        rootView.tableView.registerClassForCell(SearchPeopleTableCell.self)

        rootView.tableView.tableFooterView = UIView()

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self

        rootView.navigationBar.backButton.addTarget(self, action: #selector(backButtonClicked), for: .touchUpInside)
    }

    private func applyState(_ state: SearchPeopleViewState) {
        switch state {
        case .empty:
            rootView.tableView.isHidden = true
        case .loaded:
            rootView.tableView.isHidden = false
            rootView.tableView.reloadData()
        case .error:
            break
        }
    }

    @objc private func backButtonClicked() {
        presenter.didTapBackButton()
    }
}

extension SearchPeopleViewController: SearchPeopleViewProtocol {
    func didReceive(title: String?) {
        rootView.navigationTitleLabel.text = title
    }

    func didReceive(state: SearchPeopleViewState) {
        self.state = state
        applyState(state)
    }
}

extension SearchPeopleViewController: UITableViewDelegate, UITableViewDataSource {
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

        return viewModel.results.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard case let .loaded(viewModel) = state else {
            return UITableViewCell()
        }

        guard let cell = tableView.dequeueReusableCellWithType(SearchPeopleTableCell.self)
        else {
            return UITableViewCell()
        }

        cell.bind(to: viewModel.results[indexPath.row])
        return cell
    }
}

extension SearchPeopleViewController: UITextFieldDelegate {
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
