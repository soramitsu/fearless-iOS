import UIKit
import SoraFoundation
import SoraUI

final class SearchPeopleViewController: UIViewController, ViewHolder {
    typealias RootViewType = SearchPeopleViewLayout

    let presenter: SearchPeoplePresenterProtocol

    private var state: SearchPeopleViewState = .empty
    private var locale = Locale.current

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

        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    func configure() {
        rootView.searchField.delegate = self

        rootView.tableView.registerClassForCell(SearchPeopleTableCell.self)

        rootView.tableView.tableFooterView = UIView()

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self

        rootView.navigationBar.backButton.addTarget(self, action: #selector(backButtonClicked), for: .touchUpInside)
        rootView.scanButton.addTarget(self, action: #selector(scanButtonClicked), for: .touchUpInside)

        applyState(state)
    }

    private func applyState(_ state: SearchPeopleViewState) {
        switch state {
        case .empty:
            rootView.tableView.isHidden = true
        case .loaded:
            rootView.tableView.isHidden = false
            rootView.tableView.reloadData()
        case .error:
            rootView.tableView.isHidden = true
        }

        reloadEmptyState(animated: false)
    }

    @objc private func backButtonClicked() {
        presenter.didTapBackButton()
    }

    @objc private func scanButtonClicked() {
        presenter.didTapScanButton()
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

    func didReceive(locale: Locale) {
        self.locale = locale
        rootView.locale = locale
    }

    func didReceive(input: String) {
        rootView.searchField.text = input
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

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard case let .loaded(viewModel) = state else {
            return
        }

        presenter.didSelectViewModel(viewModel: viewModel.results[indexPath.row])
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

extension SearchPeopleViewController: HiddableBarWhenPushed {}

extension SearchPeopleViewController: LoadableViewProtocol {
    var loadableContentView: UIView! { rootView.statusView }
}

extension SearchPeopleViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
    var contentViewForEmptyState: UIView { rootView.statusView }
}

extension SearchPeopleViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        switch state {
        case .empty, .error:
            var errorMessage: String
            if rootView.searchField.text?.isEmpty == false {
                errorMessage = R.string.localizable.walletSearchEmptyTitle_v1100(preferredLanguages: locale.rLanguages)
            } else {
                errorMessage = R.string.localizable.commonSearchStartTitle(preferredLanguages: locale.rLanguages)
            }

            let emptyView = EmptyStateView()
            emptyView.image = R.image.iconEmptyHistory()
            emptyView.title = errorMessage
            emptyView.titleColor = R.color.colorLightGray()!
            emptyView.titleFont = .p2Paragraph
            return emptyView
        case .loaded:
            return nil
        }
    }
}

extension SearchPeopleViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        switch state {
        case .error, .empty:
            return true
        case .loaded:
            return false
        }
    }
}

extension SearchPeopleViewController: ErrorStateViewDelegate {
    func didRetry(errorView _: ErrorStateView) {
//        presenter.refresh(shouldReset: true)
    }
}
