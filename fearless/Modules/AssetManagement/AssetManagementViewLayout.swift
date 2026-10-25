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

    let doneButton: PortfolioActionButton = {
        let button = PortfolioActionButton()
        button.configuration?.background.backgroundColor = .clear
        button.configuration?.baseForegroundColor = R.color.colorPink()
        button.contentHorizontalAlignment = .leading
        return button
    }()

    let filterNetworksButton: PortfolioActionButton = {
        let button = PortfolioActionButton()
        button.configuration?.image = UIImage(systemName: "chevron.down")
        button.configuration?.imagePlacement = .trailing
        button.configuration?.imagePadding = 8
        button.configuration?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
            pointSize: 14,
            weight: .semibold
        )
        return button
    }()

    let headerStack = UIStackView()
    // UITableView owns this view's frame. Auto Layout only sizes its contents.
    private let headerContainer = UIView()
    let emptyResultsLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorStrokeGray()
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.isHidden = true
        return label
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

    let visibilityFilterScrollView = UIScrollView()
    let visibilityFilterStack = UIStackView()
    let resetOrderButton: PortfolioActionButton = {
        let button = PortfolioActionButton()
        button.isHidden = true
        return button
    }()

    let visibilityFilterButtons: [(ManageAssetsFilter, UIButton)] = ManageAssetsFilter.allCases.map { filter in
        let button = UIButton(type: .custom)
        button.titleLabel?.font = .p2Paragraph
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        button.layer.cornerRadius = 12
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return (filter, button)
    }

    private var pendingVisibleFilter: ManageAssetsFilter?
    private var headerNeedsSizing = true
    private var headerWidth: CGFloat = 0
    private var headerCategory: UIContentSizeCategory?

    func setVisibilityFilter(_ filter: ManageAssetsFilter) {
        pendingVisibleFilter = filter
        headerNeedsSizing = true
        setNeedsLayout()
        for (item, button) in visibilityFilterButtons {
            button.isSelected = item == filter
            button.accessibilityTraits = item == filter ? [.button, .selected] : [.button]
            button.backgroundColor = item == filter ? R.color.colorWhite8() : .clear
            button.setTitleColor(R.color.colorWhite(), for: .normal)
            button.setTitleColor(R.color.colorPink(), for: .selected)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // The table is nested in container, so its width is not settled by the
        // root view's layout pass alone (including the first on-screen pass).
        container.layoutIfNeeded()
        if tableView.bounds.width > 0,
           headerNeedsSizing || headerWidth != tableView.bounds.width || headerCategory != traitCollection
           .preferredContentSizeCategory {
            headerNeedsSizing = false
            headerWidth = tableView.bounds.width
            headerCategory = traitCollection.preferredContentSizeCategory
            let width = tableView.bounds.width
            let height = ceil(headerContainer.systemLayoutSizeFitting(
                CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            ).height)
            headerContainer.frame.size = CGSize(width: width, height: height)
            tableView.tableHeaderView = headerContainer
            headerContainer.setNeedsLayout()
            headerContainer.layoutIfNeeded()
        }
        guard let filter = pendingVisibleFilter,
              let button = visibilityFilterButtons.first(where: { $0.0 == filter })?.1,
              button.bounds.width > 0, visibilityFilterScrollView.bounds.width > 0 else { return }
        visibilityFilterScrollView.scrollRectToVisible(
            button.convert(button.bounds, to: visibilityFilterScrollView),
            animated: false
        )
        pendingVisibleFilter = nil
    }

    let manageAssetStubLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    let container = UIView()
    let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.separatorStyle = .none
        tableView.backgroundColor = R.color.colorBlack19()
        tableView.tableFooterView = UIView()
        tableView.refreshControl = UIRefreshControl()
        return tableView
    }()

    let addAssetButton: TriangularedButton = {
        UIFactory.default.createMainActionButton()
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        updateTypography()
        if #available(iOS 17.0, *) {
            registerForTraitChanges(
                [UITraitPreferredContentSizeCategory.self, UITraitLegibilityWeight.self]
            ) { (view: AssetManagementViewLayout, _: UITraitCollection) in
                view.updateTypography()
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 17.0, *) { return }
        updateTypography()
    }

    private func updateTypography() {
        guard FWAppearance.assetManagementRestyled else { return }
        manageAssetStubLabel.font = .fw(.titleS, compatibleWith: traitCollection)
        emptyResultsLabel.font = .fw(.bodyM, compatibleWith: traitCollection)
        for (_, button) in visibilityFilterButtons {
            button.titleLabel?.font = .fw(.labelM, compatibleWith: traitCollection)
            button.invalidateIntrinsicContentSize()
        }
        headerNeedsSizing = true
        setNeedsLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setAddAssetButton(visible: Bool) {
        addAssetButton.isHidden = visible
    }

    func setFilter(title: String) {
        filterNetworksButton.setTitle(title, for: .normal)
        headerNeedsSizing = true
        setNeedsLayout()
        filterNetworksButton.accessibilityValue = title
    }

    // MARK: - Private methods

    private func setupLayout() {
        backgroundColor = R.color.colorBlack19()
        [navigationBar, container, addAssetButton].forEach { addSubview($0) }
        container.addSubview(tableView)
        navigationBar.addSubview(doneButton)
        doneButton.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(8)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.greaterThanOrEqualTo(44)
        }
        navigationBar.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.height.greaterThanOrEqualTo(68)
        }
        setupTableHeader()

        container.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
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
        updateTypography()
        headerNeedsSizing = true
        filterNetworksButton.accessibilityLabel = PortfolioStrings.text("ux.choose_network", locale: locale)
        emptyResultsLabel.text = R.string.localizable.emptyViewDescription(preferredLanguages: locale.rLanguages)
        setNeedsLayout()
        resetOrderButton.setTitle(PortfolioStrings.text("manage_assets.reset_order", locale: locale), for: .normal)
        for (filter, button) in visibilityFilterButtons {
            button.setTitle(PortfolioStrings.text("manage_assets." + filter.rawValue, locale: locale), for: .normal)
        }
        manageAssetStubLabel.text = R.string.localizable.walletManageAssets(preferredLanguages: locale.rLanguages)
        tableView.accessibilityLabel = manageAssetStubLabel.text
        doneButton.setTitle(R.string.localizable.commonDone(preferredLanguages: locale.rLanguages), for: .normal)
        searchTextField.textField.placeholder = R.string.localizable.commonSearch(preferredLanguages: locale.rLanguages)
    }
}

private extension AssetManagementViewLayout {
    func setupTableHeader() {
        headerStack.axis = .vertical
        headerStack.spacing = 16
        headerStack.isLayoutMarginsRelativeArrangement = true
        headerStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 8,
            leading: UIConstants.bigOffset,
            bottom: 16,
            trailing: UIConstants.bigOffset
        )
        [
            filterNetworksButton,
            searchTextField,
            visibilityFilterScrollView,
            resetOrderButton,
            manageAssetStubLabel,
            emptyResultsLabel
        ].forEach(headerStack.addArrangedSubview)
        headerContainer.addSubview(headerStack)
        headerStack.snp.makeConstraints { $0.edges.equalToSuperview() }
        // Attach before measurement so configured controls inherit this screen's traits.
        headerContainer.frame.size.height = 1
        tableView.tableHeaderView = headerContainer
        filterNetworksButton.snp.makeConstraints { $0.height.greaterThanOrEqualTo(44) }
        resetOrderButton.snp.makeConstraints { $0.height.greaterThanOrEqualTo(44).priority(999) }

        visibilityFilterScrollView.showsHorizontalScrollIndicator = false
        visibilityFilterScrollView.addSubview(visibilityFilterStack)
        visibilityFilterStack.axis = .horizontal
        visibilityFilterStack.spacing = 8
        for (_, button) in visibilityFilterButtons {
            visibilityFilterStack.addArrangedSubview(button)
            button.snp.makeConstraints { $0.height.greaterThanOrEqualTo(44); $0.width.greaterThanOrEqualTo(44) }
        }
        visibilityFilterStack.snp.makeConstraints { make in
            make.edges.equalTo(visibilityFilterScrollView.contentLayoutGuide)
            make.height.equalTo(visibilityFilterScrollView.frameLayoutGuide)
        }
    }
}
