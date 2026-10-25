import UIKit
import SoraUI
import SnapKit

/// A multiline native control keeps the action readable at accessibility text sizes.
final class PortfolioActionButton: UIButton {
    private let shapeMask = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        var config = UIButton.Configuration.plain()
        config.background.backgroundColor = UIColor(named: "fwSurfaceRaised2")
        config.background.cornerRadius = 0
        config.baseForegroundColor = UIColor(named: "fwTextPrimary")
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        config.titleLineBreakMode = .byWordWrapping
        config.titleAlignment = .center
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { [weak self] attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: .headline, compatibleWith: self?.traitCollection)
            return attributes
        }
        configuration = config
        titleLabel?.numberOfLines = 0
        titleLabel?.adjustsFontForContentSizeCategory = true
        layer.mask = shapeMask
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitPreferredContentSizeCategory
                    .self]) { (button: PortfolioActionButton, _: UITraitCollection) in
                button.setNeedsUpdateConfiguration()
                button.invalidateIntrinsicContentSize()
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shapeMask.path = FWChamferPath.path(in: bounds).cgPath
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 17.0, *) { return }
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            setNeedsUpdateConfiguration()
            invalidateIntrinsicContentSize()
        }
    }

    func set(loading: Bool) {
        configuration?.showsActivityIndicator = loading
        isEnabled = !loading
    }
}

final class ChainAssetListViewLayout: UIView {
    private enum Constants {
        static let tableViewContentInset = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: UIConstants.actionHeight,
            right: 0
        )
    }

    var locale: Locale? {
        didSet {
            let locale = locale ?? .current
            lensControl.setTitle(PortfolioStrings.text("portfolio.lens.tokens", locale: locale), forSegmentAt: 0)
            lensControl.setTitle(PortfolioStrings.text("portfolio.lens.networks", locale: locale), forSegmentAt: 1)
            customOrderLabel.text = PortfolioStrings.text("portfolio.custom_order", locale: locale)
        }
    }

    let lensControl = PortfolioLensControl()

    let customOrderLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = UIColor(named: "fwTextSecondary")
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.isHidden = true
        return label
    }()

    enum ViewState {
        case normal
        case empty
    }

    var keyboardAdoptableConstraint: Constraint?

    weak var bannersView: UIView?

    var headerViewContainer: UIStackView = {
        let view = UIFactory.default.createVerticalStackView(spacing: UIConstants.bigOffset)
        view.alignment = .center
        return view
    }()

    let containerView = UIView()
    let tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .grouped)
        view.backgroundColor = .clear
        view.separatorStyle = .none
        view.sectionFooterHeight = .leastNormalMagnitude
        view.estimatedSectionFooterHeight = 0
        view.contentInset = Constants.tableViewContentInset
        view.refreshControl = UIRefreshControl()
        return view
    }()

    var isAnimating = false
    private var footerSizingWidth: CGFloat = 0
    private var footerSizingCategory: UIContentSizeCategory?

    /// What the header total leaves out, above Manage assets.
    let exclusionsView = PortfolioExclusionsView()
    /// Above the list until answered: hidden assets from the previous version hold funds.
    let hiddenFundsNoticeView = PortfolioHiddenFundsNoticeView()
    let emptyWalletView = PortfolioEmptyWalletView()
    private let headerContainer = UIView()
    private var headerNeedsSizing = true
    private var headerWidth: CGFloat = 0
    private var headerCategory: UIContentSizeCategory?

    // MARK: - Manage button

    let footerButton = PortfolioActionButton()

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
        if FWAppearance.portfolioListRestyled {
            customOrderLabel.font = .fw(.bodyS, compatibleWith: traitCollection)
        }
        containerView.layoutIfNeeded()
        if tableView.tableHeaderView === headerContainer, tableView.bounds.width > 0,
           headerNeedsSizing || headerWidth != tableView.bounds.width || headerCategory != traitCollection
           .preferredContentSizeCategory {
            headerNeedsSizing = false
            headerWidth = tableView.bounds.width
            headerCategory = traitCollection.preferredContentSizeCategory
            let height = ceil(headerContainer.systemLayoutSizeFitting(
                CGSize(width: headerWidth, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel
            ).height)
            headerContainer.frame.size = CGSize(width: headerWidth, height: height)
            tableView.tableHeaderView = headerContainer
            headerContainer.setNeedsLayout()
            headerContainer.layoutIfNeeded()
        }
        if tableView.tableFooterView != nil,
           footerSizingWidth != tableView.bounds.width || footerSizingCategory != traitCollection
           .preferredContentSizeCategory {
            setFooterView()
        }
    }

    func addBanners(view: UIView) {
        bannersView = view
        bannersView?.isHidden = true
        headerViewContainer.addArrangedSubview(view)
        view.snp.makeConstraints { make in
            make.width.equalToSuperview().inset(UIConstants.bigOffset)
        }
    }

    func setHeaderView() {
        if headerViewContainer.superview !== headerContainer {
            headerContainer.addSubview(headerViewContainer)
            headerViewContainer.snp.remakeConstraints { $0.edges.equalToSuperview() }
        }
        headerContainer.frame.size.height = max(headerContainer.frame.height, 1)
        tableView.tableHeaderView = headerContainer
        headerNeedsSizing = true
        setNeedsLayout()
    }

    func removeHeaderView() {
        tableView.tableHeaderView = nil
    }

    func setFooterView() {
        // Before the first layout pass the table has no width yet; the captions wrap
        // against the screen width then.
        let width = tableView.bounds.width > 0 ? tableView.bounds.width : UIScreen.main.bounds.width
        let footerContainer = UIView(frame: CGRect(origin: .zero, size: CGSize(width: width, height: 0)))
        footerContainer.addSubview(exclusionsView)
        footerContainer.addSubview(footerButton)
        exclusionsView.snp.remakeConstraints { make in
            make.top.equalToSuperview().inset(exclusionsView.isHidden ? 0 : 16)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            if exclusionsView.isHidden {
                make.height.equalTo(0)
            }
        }
        footerButton.snp.remakeConstraints { make in
            make.top.equalTo(exclusionsView.snp.bottom).offset(16)
            make.bottom.equalToSuperview().inset(16)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.greaterThanOrEqualTo(UIConstants.actionHeight)
        }
        // Attach before measuring so Dynamic Type uses this controller's traits.
        // Measuring a detached footer gives it the app window's default font size.
        tableView.tableFooterView = footerContainer
        footerContainer.setNeedsLayout()
        footerContainer.layoutIfNeeded()
        let height = footerContainer.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        footerContainer.frame.size.height = max(height, UIConstants.actionHeight + 32)
        footerSizingWidth = tableView.bounds.width
        footerSizingCategory = traitCollection.preferredContentSizeCategory
        tableView.tableFooterView = footerContainer
    }

    func removeFooterView() {
        exclusionsView.removeFromSuperview()
        footerButton.removeFromSuperview()
        tableView.tableFooterView = nil
    }

    func viewForEmptyState(for state: AssetListState) -> UIView {
        let emptyView = EmptyView()
        emptyView.image = R.image.iconWarning()
        emptyView.title = R.string.localizable.emptyViewTitle(preferredLanguages: locale?.rLanguages)
        emptyView.text = emptyViewText(for: state)
        emptyView.iconMode = .bigFilledShadow

        let container = ScrollableContainerView()
        container.stackView.spacing = 0
        container.stackView.alignment = .fill
        container.stackView.distribution = .equalSpacing
        container.scrollBottomOffset = 116
        container.addArrangedSubview(headerViewContainer)
        container.addArrangedSubview(emptyView)
        container.addArrangedSubview(footerButton)

        headerViewContainer.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.width.equalToSuperview()
        }

        container.stackView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
            make.height.greaterThanOrEqualToSuperview()
        }

        footerButton.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.greaterThanOrEqualTo(UIConstants.actionHeight)
        }

        return container
    }

    func runManageAssetAnimate(finish: @escaping (() -> Void)) {
        isAnimating = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let rect = self.tableView.convert(
                self.footerButton.bounds,
                from: self.tableView.tableFooterView
            )
            self.tableView.scrollRectToVisible(
                rect,
                animated: true
            )

            UIView.animate(
                withDuration: 0.6,
                delay: 0.2,
                animations: {
                    self.footerButton.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                },
                completion: { _ in
                    UIView.animate(withDuration: 0.6) {
                        self.footerButton.transform = CGAffineTransform.identity
                        finish()
                        self.isAnimating = false
                    }
                }
            )
        }
    }

    func setFooterButtonTitle(for state: AssetListState) {
        let title: String?
        switch state {
        case .defaultList, .allIsHidden:
            title = R.string.localizable.walletManageAssets(preferredLanguages: locale?.rLanguages)
        case .chainHasNetworkIssue:
            title = R.string.localizable.tryAgain(preferredLanguages: locale?.rLanguages)
        case .chainHasAccountIssue:
            title = R.string.localizable.accountsAddAccount(preferredLanguages: locale?.rLanguages)
        case .search:
            title = nil
        }
        footerButton.setTitle(title, for: .normal)
    }

    private func setupLayout() {
        headerViewContainer.addArrangedSubview(lensControl)
        headerViewContainer.addArrangedSubview(customOrderLabel)
        lensControl.snp.makeConstraints { make in
            make.width.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.greaterThanOrEqualTo(44)
        }
        customOrderLabel.snp.makeConstraints { make in
            make.width.equalToSuperview().inset(UIConstants.bigOffset)
        }
        headerViewContainer.addArrangedSubview(hiddenFundsNoticeView)
        hiddenFundsNoticeView.snp.makeConstraints { make in
            make.width.equalToSuperview().inset(UIConstants.bigOffset)
        }

        headerViewContainer.addArrangedSubview(emptyWalletView)
        emptyWalletView.snp.makeConstraints { $0.width.equalToSuperview().inset(UIConstants.bigOffset) }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            keyboardAdoptableConstraint = make.bottom.equalToSuperview().constraint
        }

        containerView.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func emptyViewText(for state: AssetListState) -> String? {
        switch state {
        case .defaultList:
            return nil
        case .allIsHidden:
            return R.string.localizable.walletAllAssetsHidden(preferredLanguages: locale?.rLanguages)
        case .chainHasNetworkIssue:
            return "Connection Error: Unable to connect to the network. Please try again."
        case .chainHasAccountIssue:
            return R.string.localizable.accountNeededMessage(preferredLanguages: locale?.rLanguages)
        case .search:
            return R.string.localizable.emptyViewDescription(preferredLanguages: locale?.rLanguages)
        }
    }
}

/// The labels under the portfolio for what the header total leaves out: hidden and testnet
/// assets (buttons that open Manage assets), assets without a trusted price and pool stakes.
final class PortfolioExclusionsView: UIView {
    var onTapHiddenAssets: (() -> Void)?
    var onTapTestnetAssets: (() -> Void)?

    private let stackView: UIStackView = {
        let stackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.minimalOffset)
        stackView.alignment = .leading
        return stackView
    }()

    private(set) var captions: [PortfolioExclusionCaption] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(captions: [PortfolioExclusionCaption]) {
        self.captions = captions
        for subview in stackView.arrangedSubviews {
            subview.removeFromSuperview()
        }
        for caption in captions {
            stackView.addArrangedSubview(view(for: caption))
        }
        isHidden = captions.isEmpty
    }

    private func view(for caption: PortfolioExclusionCaption) -> UIView {
        switch caption.kind {
        case .hiddenAssets:
            return manageButton(title: caption.text, action: #selector(didTapHiddenAssets))
        case .testnetAssets:
            return manageButton(title: caption.text, action: #selector(didTapTestnetAssets))
        case .unpricedAssets, .poolStakes:
            let label = UILabel()
            label.text = caption.text
            label.font = .p2Paragraph
            label.textColor = R.color.colorLightGray()
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
            return label
        }
    }

    private func manageButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(R.color.colorPink(), for: .normal)
        button.titleLabel?.font = .p2Paragraph
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.contentHorizontalAlignment = .leading
        button.accessibilityTraits = .button
        button.addTarget(self, action: action, for: .touchUpInside)
        button.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(44)
        }
        return button
    }

    @objc private func didTapHiddenAssets() {
        onTapHiddenAssets?()
    }

    @objc private func didTapTestnetAssets() {
        onTapTestnetAssets?()
    }
}

/// "N hidden assets hold funds": Review opens Manage assets, Keep hidden dismisses the notice
/// for those assets. Nothing is unhidden on the user's behalf.
final class PortfolioHiddenFundsNoticeView: UIView {
    var onReview: (() -> Void)?
    var onKeepHidden: (() -> Void)?

    private let backgroundView: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = R.color.colorWhite8()!
        view.highlightedFillColor = R.color.colorWhite8()!
        view.shadowOpacity = 0
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.accessibilityTraits = .header
        return label
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    let reviewButton = PortfolioHiddenFundsNoticeView.makeButton()
    let keepHiddenButton = PortfolioHiddenFundsNoticeView.makeButton()
    private let buttonsStack = UIFactory.default.createHorizontalStackView(spacing: UIConstants.defaultOffset)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        isHidden = true
        reviewButton.addAction { [weak self] in
            self?.onReview?()
        }
        keepHiddenButton.addAction { [weak self] in
            self?.onKeepHidden?()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateButtonsAxis()
    }

    func bind(_ notice: PortfolioHiddenFundsNotice?) {
        titleLabel.text = notice?.title
        messageLabel.text = notice?.message
        reviewButton.imageWithTitleView?.title = NSLocalizedString(
            "portfolio.hidden_funds.review",
            value: "Review",
            comment: "Notice above the portfolio: opens Manage assets"
        )
        keepHiddenButton.imageWithTitleView?.title = NSLocalizedString(
            "portfolio.hidden_funds.keep_hidden",
            value: "Keep hidden",
            comment: "Notice above the portfolio: dismisses it"
        )
        isHidden = notice == nil
    }

    private static func makeButton() -> TriangularedButton {
        let button = TriangularedButton()
        button.triangularedView?.shadowOpacity = 0
        button.triangularedView?.fillColor = R.color.colorWhite8()!
        button.triangularedView?.highlightedFillColor = R.color.colorWhite8()!
        button.imageWithTitleView?.titleColor = R.color.colorWhite()!
        button.imageWithTitleView?.titleFont = .h6Title
        return button
    }

    private func updateButtonsAxis() {
        let isLargeText = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        buttonsStack.axis = isLargeText ? .vertical : .horizontal
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let contentStack = UIFactory.default.createVerticalStackView(spacing: UIConstants.minimalOffset)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(messageLabel)
        contentStack.setCustomSpacing(UIConstants.defaultOffset, after: messageLabel)
        contentStack.addArrangedSubview(buttonsStack)
        buttonsStack.distribution = .fillEqually
        buttonsStack.addArrangedSubview(reviewButton)
        buttonsStack.addArrangedSubview(keepHiddenButton)
        for button in [reviewButton, keepHiddenButton] {
            button.snp.makeConstraints { make in
                make.height.greaterThanOrEqualTo(44)
            }
        }
        updateButtonsAxis()

        backgroundView.addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIConstants.bigOffset)
        }
    }
}

/// Two native buttons can wrap at accessibility sizes while retaining the existing lens action contract.
final class PortfolioLensControl: UIControl {
    private let legacy = UISegmentedControl(items: ["", ""])
    private let stack = UIStackView()
    let segmentButtons = [UIButton(type: .system), UIButton(type: .system)]

    var selectedSegmentIndex = 0 {
        didSet { updatePresentation() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        if FWAppearance.portfolioListRestyled {
            accessibilityTraits = .tabBar
            backgroundColor = UIColor(named: "fwSurfaceSunken")
            layer.borderWidth = 1
            layer.borderColor = UIColor(named: "fwStrokeControl")?.cgColor
            layer.cornerRadius = FWTokens.Radius.m
            stack.spacing = 4
            stack.distribution = .fillEqually
            addSubview(stack)
            stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(4) }
            for (index, button) in segmentButtons.enumerated() {
                button.tag = index
                button.titleLabel?.numberOfLines = 0
                button.titleLabel?.lineBreakMode = .byWordWrapping
                button.titleLabel?.textAlignment = .center
                var config = UIButton.Configuration.plain()
                config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
                config.titleLineBreakMode = .byWordWrapping
                config.titleAlignment = .center
                config.baseForegroundColor = UIColor(named: "fwTextPrimary")
                config
                    .titleTextAttributesTransformer =
                    UIConfigurationTextAttributesTransformer { [weak button] attributes in
                        var attributes = attributes
                        attributes.font = UIFont.fw(.labelM, compatibleWith: button?.traitCollection)
                        return attributes
                    }
                button.configuration = config
                button.layer.cornerRadius = FWTokens.Radius.m
                button.addTarget(self, action: #selector(didSelectButton(_:)), for: .touchUpInside)
                stack.addArrangedSubview(button)
                button.snp.makeConstraints { $0.height.greaterThanOrEqualTo(44) }
            }
        } else {
            legacy.selectedSegmentTintColor = UIColor(named: "fwSurfaceRaised2")
            legacy.backgroundColor = UIColor(named: "fwSurfaceGlass")
            legacy.setTitleTextAttributes([.foregroundColor: UIColor(named: "fwTextPrimary") ?? .white], for: .normal)
            legacy.addTarget(self, action: #selector(didSelectLegacy), for: .valueChanged)
            addSubview(legacy)
            legacy.snp.makeConstraints { $0.edges.equalToSuperview() }
        }
        updatePresentation()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setTitle(_ title: String?, forSegmentAt index: Int) {
        guard segmentButtons.indices.contains(index) else { return }
        legacy.setTitle(title, forSegmentAt: index)
        segmentButtons[index].setTitle(title, for: .normal)
        invalidateIntrinsicContentSize()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updatePresentation()
    }

    private func updatePresentation() {
        legacy.selectedSegmentIndex = selectedSegmentIndex
        guard FWAppearance.portfolioListRestyled else { return }
        stack.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
        for (index, button) in segmentButtons.enumerated() {
            let selected = index == selectedSegmentIndex
            button.setNeedsUpdateConfiguration()
            button.isSelected = selected
            button.accessibilityTraits = selected ? [.button, .selected] : .button
            var config = button.configuration
            config?.background.backgroundColor = selected ? UIColor(named: "fwSurfaceRaised2") : .clear
            config?.baseForegroundColor = UIColor(named: selected ? "fwTextPrimary" : "fwTextSecondary")
            button.configuration = config
            button.layer.borderWidth = selected ? 1 : 0
            button.layer.borderColor = UIColor(named: "fwAccentEdge")?.cgColor
            button.invalidateIntrinsicContentSize()
        }
        invalidateIntrinsicContentSize()
    }

    @objc private func didSelectButton(_ button: UIButton) {
        selectedSegmentIndex = button.tag
        sendActions(for: .valueChanged)
    }

    @objc private func didSelectLegacy() {
        selectedSegmentIndex = legacy.selectedSegmentIndex
        sendActions(for: .valueChanged)
    }
}
