import UIKit
import SnapKit

final class AssetManagementViewLayout: UIView {
    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    var keyboardAdoptableConstraint: Constraint?

    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar(backButtonAlignment: .clear)
        bar.backgroundColor = R.color.colorBlack19()
        return bar
    }()

    let doneButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(R.color.colorPink(), for: .normal)
        button.titleLabel?.font = .p0Paragraph
        return button
    }()

    let filterNetworksButton: UIButton = {
        let button = UIButton()
        button.titleLabel?.font = .p0Paragraph
        return button
    }()

    let searchTextField: SearchTextField = {
        let searchTextField = SearchTextField()
        searchTextField.triangularedView?.cornerCut = [.bottomRight, .topLeft]
        searchTextField.triangularedView?.strokeWidth = UIConstants.separatorHeight
        searchTextField.triangularedView?.strokeColor = R.color.colorStrokeGray() ?? .lightGray
        searchTextField.triangularedView?.fillColor = R.color.colorWhite8()!
        searchTextField.triangularedView?.highlightedFillColor = R.color.colorWhite8()!
        searchTextField.triangularedView?.shadowOpacity = 0
        searchTextField.backgroundColor = R.color.colorBlack19()
        return searchTextField
    }()

    let manageAssetStubLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        return label
    }()

    let container = UIView()
    let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.separatorStyle = .none
        tableView.backgroundColor = R.color.colorBlack19()
        tableView.tableFooterView = UIView()
        return tableView
    }()

    let addAssetButton: TriangularedButton = {
        UIFactory.default.createMainActionButton()
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        navigationBar.setLeftViews([doneButton])
        navigationBar.setRightViews([filterNetworksButton])
    }

    func setAddAssetButton(visible: Bool) {
        addAssetButton.isHidden = visible
    }

    func setFilter(title: String) {
        filterNetworksButton.setTitle(title, for: .normal)
    }

    // MARK: - Private methods

    private func setupLayout() {
        backgroundColor = R.color.colorBlack19()
        [
            navigationBar,
            searchTextField,
            manageAssetStubLabel,
            container,
            addAssetButton
        ].forEach { addSubview($0) }
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

        manageAssetStubLabel.snp.makeConstraints { make in
            make.top.equalTo(searchTextField.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        container.snp.makeConstraints { make in
            make.top.equalTo(manageAssetStubLabel.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.trailing.equalToSuperview()
            keyboardAdoptableConstraint = make.bottom.equalToSuperview().constraint
        }

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addAssetButton.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    private func applyLocalization() {
        manageAssetStubLabel.text = R.string.localizable.walletManageAssets(preferredLanguages: locale.rLanguages)
        doneButton.setTitle(R.string.localizable.commonDone(preferredLanguages: locale.rLanguages), for: .normal)
        searchTextField.textField.placeholder = R.string.localizable.commonSearch(preferredLanguages: locale.rLanguages)
    }
}
