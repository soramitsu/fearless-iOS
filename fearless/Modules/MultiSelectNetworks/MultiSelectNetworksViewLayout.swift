import UIKit
import SnapKit

final class MultiSelectNetworksViewLayout: UIView {
    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    var keyboardAdoptableConstraint: Constraint?

    let navigationBar: UIStackView = {
        let view = UIFactory.default.createHorizontalStackView()
        view.distribution = .equalSpacing
        view.backgroundColor = R.color.colorBlack19()
        return view
    }()

    lazy var searchTextField: SearchTextField = {
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

    let selectAllButton: UIButton = {
        let button = UIButton()
        button.imageView?.image = nil
        button.setTitleColor(R.color.colorPink(), for: .normal)
        button.titleLabel?.font = .p0Paragraph
        return button
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        return label
    }()

    let doneButton: UIButton = {
        let button = UIButton()
        button.titleLabel?.font = .p0Paragraph
        return button
    }()

    let container = UIView()
    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = R.color.colorBlack19()
        return tableView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlack19()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func handleSelectAllButton(allSelected: Bool) {
        allSelected
            ? selectAllButton.setTitle(R.string.localizable.stakingCustomDeselectButtonTitle(preferredLanguages: locale.rLanguages), for: .normal)
            : selectAllButton.setTitle(R.string.localizable.commonSelectAll(preferredLanguages: locale.rLanguages), for: .normal)
    }

    func setTitle(text: String) {
        titleLabel.text = text
    }

    // MARK: - Private methods

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(searchTextField)
        addSubview(container)
        container.addSubview(tableView)

        navigationBar.addArrangedSubview(selectAllButton)
        navigationBar.addArrangedSubview(titleLabel)
        navigationBar.addArrangedSubview(doneButton)

        navigationBar.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(56)
        }

        searchTextField.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        container.snp.makeConstraints { make in
            make.top.equalTo(searchTextField.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            keyboardAdoptableConstraint = make.bottom.equalTo(safeAreaLayoutGuide).constraint
        }

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func applyLocalization() {
        selectAllButton.setTitle(R.string.localizable.commonSelectAll(preferredLanguages: locale.rLanguages), for: .normal)
        doneButton.setTitle(R.string.localizable.commonDone(preferredLanguages: locale.rLanguages), for: .normal)
        searchTextField.textField.placeholder = R.string.localizable.commonSearch(preferredLanguages: locale.rLanguages)
    }
}
