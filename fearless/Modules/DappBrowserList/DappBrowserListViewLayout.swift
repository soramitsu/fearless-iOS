import UIKit
import SnapKit

final class DappBrowserListViewLayout: UIView {

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    var keyboardAdoptableConstraint: Constraint?

    let navigationBar: BaseNavigationBar = {
        let view = BaseNavigationBar()
        view.set(.present)
        view.backgroundColor = R.color.colorBlack19()
        return view
    }()

    let searchTextField: SearchTextField = {
        let searchTextField = SearchTextField()
        searchTextField.triangularedView?.cornerCut = [.bottomRight, .topLeft]
        searchTextField.triangularedView?.strokeWidth = 1
        searchTextField.triangularedView?.strokeColor = R.color.colorWhite8()!
        searchTextField.triangularedView?.fillColor = R.color.colorBlack50()!
        searchTextField.triangularedView?.highlightedFillColor = R.color.colorBlack50()!
        searchTextField.triangularedView?.shadowOpacity = 0
        searchTextField.textField.backgroundColor = R.color.colorBlack50()
        searchTextField.textField.tintColor = R.color.colorWhite50()
        return searchTextField
    }()

    let container = UIView()
    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = R.color.colorBlack19()
        return tableView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Private methods

    private func setupLayout() {
        backgroundColor = R.color.colorBlack19()
        addSubview(navigationBar)
        addSubview(searchTextField)
        addSubview(container)
        container.addSubview(tableView)

        navigationBar.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(56)
        }

        searchTextField.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        container.snp.makeConstraints { make in
            make.top.equalTo(searchTextField.snp.bottom).offset(UIConstants.offset12)
            make.leading.trailing.equalToSuperview()
            keyboardAdoptableConstraint = make.bottom.equalTo(safeAreaLayoutGuide).constraint
        }

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func applyLocalization() {
        searchTextField.textField.placeholder = R.string.localizable.commonSearch(preferredLanguages: locale.rLanguages)
    }
}
