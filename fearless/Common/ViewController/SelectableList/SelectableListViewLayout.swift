import UIKit
import SoraFoundation

final class SelectableListViewLayout: UIView {
    private enum Constants {
        static let headerHeight: CGFloat = 56.0
        static let cornerRadius: CGFloat = 20.0
    }

    private let searchTexts: SelectNetworkSearchTexts?

    let indicator = UIFactory.default.createIndicatorView()

    let contentStackView: UIStackView = {
        let view = UIFactory.default.createVerticalStackView(spacing: 5)
        view.alignment = .center
        return view
    }()

    let titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.font = .h3Title
        titleLabel.textAlignment = .left
        return titleLabel
    }()

    lazy var searchTextField: SearchTextField = {
        let searchTextField = SearchTextField()
        searchTextField.triangularedView?.cornerCut = [.bottomRight, .topLeft]
        searchTextField.triangularedView?.strokeWidth = UIConstants.separatorHeight
        searchTextField.triangularedView?.strokeColor = R.color.colorStrokeGray() ?? .lightGray
        searchTextField.triangularedView?.fillColor = R.color.colorWhite8()!
        searchTextField.triangularedView?.highlightedFillColor = R.color.colorWhite8()!
        searchTextField.triangularedView?.shadowOpacity = 0
        searchTextField.isHidden = searchTexts == nil
        return searchTextField
    }()

    let tableView = UITableView()
    lazy var emptyView: EmptyView = {
        let view = EmptyView()
        let viewModel = EmptyViewModel(
            title: searchTexts?.emptyViewTitle.value(for: locale) ?? "",
            description: searchTexts?.emptyViewDescription.value(for: locale) ?? ""
        )
        view.bind(viewModel: viewModel)
        return view
    }()

    var locale: Locale = .current {
        didSet {
            applyLocale()
        }
    }

    init(searchTexts: SelectNetworkSearchTexts?) {
        self.searchTexts = searchTexts
        super.init(frame: .zero)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func emtyView(isHidden: Bool) {
        emptyView.isHidden = isHidden
        tableView.isHidden = !isHidden
    }

    private func applyLocale() {
        titleLabel.text = R.string.localizable.commonSelectNetwork(
            preferredLanguages: locale.rLanguages
        )
        searchTextField.textField.placeholder = searchTexts?.placeholder.value(for: locale)
    }

    private func setupLayout() {
        layer.cornerRadius = Constants.cornerRadius
        clipsToBounds = true

        let navView = UIView()
        addSubview(navView)
        navView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(Constants.headerHeight)
        }

        navView.addSubview(indicator)
        indicator.snp.makeConstraints { make in
            make.size.equalTo(UIConstants.indicatorSize)
            make.top.equalTo(navView.snp.top)
            make.centerX.equalTo(navView.snp.centerX)
        }

        navView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
        }

        addSubview(contentStackView)
        contentStackView.snp.makeConstraints { make in
            make.top.equalTo(navView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(0)
        }

        contentStackView.addArrangedSubview(searchTextField)
        contentStackView.addArrangedSubview(tableView)
        contentStackView.addArrangedSubview(emptyView)

        tableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }

        searchTextField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.horizontalInset)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        emptyView.snp.makeConstraints { make in
            make.edges.equalTo(tableView)
        }
    }
}
