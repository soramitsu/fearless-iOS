import SnapKit
import UIKit

/// The one list's discovery controls (one-list wallet home): a search field that is always on screen and a row of
/// network chips. Both narrow the same token list; neither regroups it. Sun-lit: the field is an inset well, the
/// chips are raised-1 pills and the chosen chip is pressed in with brand text.
final class PortfolioDiscoveryView: UIView {
    private enum Constants {
        /// Room around the chips for their key-light shadows inside the clipping scroll view.
        static let chipShadowRoom: CGFloat = 10
        static let minimumControlHeight: CGFloat = 44
        static let searchDelay: TimeInterval = 0.2
        static let moreChipId = "more"
    }

    let searchWell: FWNeuView = {
        let view = FWNeuView()
        view.style = .inset
        view.isInteractive = true
        view.isUserInteractionEnabled = false
        view.shape = { UIBezierPath(roundedRect: $0, cornerRadius: FWSunlit.Radius.button) }
        return view
    }()

    let searchField: UITextField = {
        let field = UITextField()
        field.borderStyle = .none
        field.textColor = FWSunlit.Palette.textPrimary
        field.tintColor = FWSunlit.Palette.brandText
        field.clearButtonMode = .whileEditing
        field.returnKeyType = .search
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.keyboardAppearance = .dark
        field.adjustsFontForContentSizeCategory = true
        field.accessibilityIdentifier = "portfolioSearch"
        return field
    }()

    let chipsScrollView: UIScrollView = {
        let view = UIScrollView()
        view.showsHorizontalScrollIndicator = false
        view.alwaysBounceHorizontal = true
        return view
    }()

    let chipsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.spacing = 10
        return stack
    }()

    let migrationCard: FWNeuView = {
        let view = FWNeuView()
        view.style = .raised1
        view.shape = { UIBezierPath(roundedRect: $0, cornerRadius: FWSunlit.Radius.row) }
        return view
    }()

    let migrationLabel = PortfolioDiscoveryView.makeCaption()
    let dismissButton = PortfolioDiscoveryView.makeTextButton(identifier: "portfolioDismissOneList")
    let searchAllButton = PortfolioDiscoveryView.makeTextButton(identifier: "portfolioSearchAllNetworks")
    let noResultsLabel = PortfolioDiscoveryView.makeCaption()

    private(set) var chipButtons: [PortfolioNetworkChipButton] = []
    private(set) var boundChips: [PortfolioNetworkChip] = []

    var onSearch: ((String) -> Void)?
    var onSelectNetwork: ((String) -> Void)?
    var onMoreNetworks: (() -> Void)?
    var onDismissMigration: (() -> Void)?
    var onSearchActiveChange: ((Bool) -> Void)?

    var locale: Locale = .current {
        didSet { applyLocalization() }
    }

    private let searchIcon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
    private let stack = UIStackView()
    private let searchRow = UIView()
    private let migrationRow = UIView()
    private let noResultsRow = UIView()
    private let searchAllRow = UIView()
    private var chipsHeight: Constraint?
    private var searchHeight: Constraint?
    private var searchIconSize: Constraint?
    private var pendingSearch: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        searchField.delegate = self
        searchField.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
        dismissButton.addAction(UIAction { [weak self] _ in self?.onDismissMigration?() }, for: .touchUpInside)
        searchAllButton.addAction(UIAction { [weak self] _ in
            self?.onSelectNetwork?(NetworkManagmentFilter.all.identifier)
        }, for: .touchUpInside)
        migrationRow.isHidden = true
        noResultsRow.isHidden = true
        searchAllRow.isHidden = true
        if #available(iOS 17.0, *) {
            // Text size and Bold Text both change the fonts.
            registerForTraitChanges(
                [UITraitPreferredContentSizeCategory.self, UITraitLegibilityWeight.self]
            ) { (view: PortfolioDiscoveryView, _: UITraitCollection) in
                view.updateTypography()
            }
        }
        applyLocalization()
        updateTypography()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 17.0, *) {
            return
        }
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory ||
            previousTraitCollection?.legibilityWeight != traitCollection.legibilityWeight {
            updateTypography()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateTypography()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        refreshSunRim()
    }

    /// The field keeps what the user is typing: the list's echo of an older keystroke never overwrites it.
    func bind(
        search: String,
        chips: [PortfolioNetworkChip],
        showsMigration: Bool,
        searchAll: Bool,
        foundNothing: Bool
    ) {
        if !searchField.isFirstResponder, pendingSearch == nil, searchField.text != search {
            searchField.text = search
        }
        migrationRow.isHidden = !showsMigration
        noResultsRow.isHidden = !foundNothing
        searchAllRow.isHidden = !searchAll
        bindChips(chips)
    }

    /// The field takes the keyboard. False when it cannot (not on screen).
    @discardableResult
    func focusSearch() -> Bool {
        guard window != nil, !isHidden else { return false }
        return searchField.isFirstResponder || searchField.becomeFirstResponder()
    }

    /// Sends a search still waiting for its pause in typing, then lets the keyboard go.
    func endSearchEditing() {
        deliverPendingSearch()
        if searchField.isFirstResponder {
            searchField.resignFirstResponder()
        }
    }

    /// The field reports what was typed after a short pause, so the list is not rebuilt for every keystroke.
    func deliverPendingSearch() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(firePendingSearch), object: nil)
        firePendingSearch()
    }

    /// The chips and the field take the sun bounce on their top rims like the rows below them.
    func refreshSunRim() {
        guard window != nil else { return }
        searchWell.sunRim = FWSunAnchor.shared.sunRim(for: searchWell)
        migrationCard.sunRim = FWSunAnchor.shared.sunRim(for: migrationCard)
        for chip in chipButtons {
            chip.surface.sunRim = FWSunAnchor.shared.sunRim(for: chip.surface)
        }
    }

    private func bindChips(_ chips: [PortfolioNetworkChip]) {
        let more = PortfolioNetworkChip(
            id: Constants.moreChipId,
            title: PortfolioStrings.text("portfolio.one_list.more", locale: locale),
            selected: false
        )
        let all = chips + [more]
        guard all != boundChips else { return }
        let selectionChanged = all.first(where: \.selected)?.id != boundChips.first(where: \.selected)?.id
        boundChips = all
        for view in chipsStack.arrangedSubviews {
            view.removeFromSuperview()
        }
        chipButtons = all.map { chip in
            let button = PortfolioNetworkChipButton(chip: chip, isMore: chip.id == Constants.moreChipId)
            button.addAction(UIAction { [weak self, weak button] _ in
                guard let self, let button, button.superview === self.chipsStack else { return }
                if button.chipId == Constants.moreChipId {
                    self.onMoreNetworks?()
                } else {
                    self.onSelectNetwork?(button.chipId)
                }
            }, for: .touchUpInside)
            chipsStack.addArrangedSubview(button)
            return button
        }
        updateTypography()
        refreshSunRim()
        // A network chosen in the full list may sit past the screen's edge: bring it into view.
        guard selectionChanged, let selected = chipButtons.first(where: \.isSelected) else { return }
        chipsStack.layoutIfNeeded()
        let frame = selected.frame.insetBy(dx: -Constants.chipShadowRoom, dy: 0)
        chipsScrollView.scrollRectToVisible(chipsStack.convert(frame, to: chipsScrollView), animated: false)
    }

    private func applyLocalization() {
        searchField.attributedPlaceholder = NSAttributedString(
            string: PortfolioStrings.text("portfolio.one_list.search", locale: locale),
            attributes: [.foregroundColor: FWSunlit.Palette.textSecondary]
        )
        migrationLabel.text = PortfolioStrings.text("portfolio.one_list.note", locale: locale)
        dismissButton.setTitle(PortfolioStrings.text("portfolio.one_list.dismiss", locale: locale), for: .normal)
        searchAllButton.setTitle(PortfolioStrings.text("portfolio.one_list.search_all", locale: locale), for: .normal)
        noResultsLabel.text = R.string.localizable.emptyViewDescription(preferredLanguages: locale.rLanguages)
        if boundChips.contains(where: { $0.id == Constants.moreChipId }) {
            let chips = boundChips.filter { $0.id != Constants.moreChipId }
            boundChips = []
            bindChips(chips)
        }
    }

    private func updateTypography() {
        let searchFont = UIFont.fw(.bodyM, locale: locale, compatibleWith: traitCollection)
        searchField.font = searchFont
        searchIconSize?.update(offset: max(18, ceil(searchFont.pointSize * 1.1)))
        searchHeight?.update(offset: max(Constants.minimumControlHeight + 4, ceil(searchFont.lineHeight) + 24))
        let chipFont = UIFont.fw(.labelM, locale: locale, compatibleWith: traitCollection)
        let chipHeight = max(Constants.minimumControlHeight, ceil(chipFont.lineHeight) + 20)
        chipsHeight?.update(offset: chipHeight + 2 * Constants.chipShadowRoom)
        for chip in chipButtons {
            chip.apply(font: chipFont)
        }
        migrationLabel.font = .fw(.bodyS, locale: locale, compatibleWith: traitCollection)
        noResultsLabel.font = .fw(.bodyS, locale: locale, compatibleWith: traitCollection)
        for button in [dismissButton, searchAllButton] {
            button.titleLabel?.font = .fw(.labelM, locale: locale, compatibleWith: traitCollection)
            button.invalidateIntrinsicContentSize()
        }
        setNeedsLayout()
    }

    @objc private func searchTextChanged() {
        pendingSearch = searchField.text ?? ""
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(firePendingSearch), object: nil)
        perform(#selector(firePendingSearch), with: nil, afterDelay: Constants.searchDelay)
    }

    @objc private func searchWellTapped() {
        focusSearch()
    }

    @objc private func firePendingSearch() {
        guard let query = pendingSearch else { return }
        pendingSearch = nil
        onSearch?(query)
    }
}

// MARK: - Layout

private extension PortfolioDiscoveryView {
    func setupLayout() {
        stack.axis = .vertical
        stack.spacing = 4
        addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }
        setupSearchRow()
        setupChips()
        setupNotes()
    }

    /// The search well, inset like the rows.
    func setupSearchRow() {
        searchRow.addSubview(searchWell)
        searchWell.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(6)
            make.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            searchHeight = make.height.equalTo(Constants.minimumControlHeight + 4).constraint
        }
        searchIcon.tintColor = FWSunlit.Palette.textSecondary
        searchIcon.contentMode = .scaleAspectFit
        searchIcon.isAccessibilityElement = false
        searchRow.addSubview(searchIcon)
        searchRow.addSubview(searchField)
        searchIcon.snp.makeConstraints { make in
            make.leading.equalTo(searchWell).offset(16)
            make.centerY.equalTo(searchWell)
            searchIconSize = make.size.equalTo(18).constraint
        }
        searchField.snp.makeConstraints { make in
            make.leading.equalTo(searchIcon.snp.trailing).offset(10)
            make.trailing.equalTo(searchWell).inset(10)
            make.top.bottom.equalTo(searchWell)
        }
        // The whole well takes a tap, icon included.
        searchRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(searchWellTapped)))
        stack.addArrangedSubview(searchRow)
    }

    /// The chips run edge to edge so they scroll under the screen's edge; the first one lines up with the rows.
    func setupChips() {
        chipsScrollView.addSubview(chipsStack)
        chipsStack.snp.makeConstraints { make in
            make.top.bottom.equalTo(chipsScrollView.contentLayoutGuide).inset(Constants.chipShadowRoom)
            make.leading.trailing.equalTo(chipsScrollView.contentLayoutGuide).inset(UIConstants.horizontalInset)
            make.height.equalTo(chipsScrollView.frameLayoutGuide).offset(-2 * Constants.chipShadowRoom)
        }
        chipsScrollView.snp.makeConstraints { make in
            chipsHeight = make.height.equalTo(Constants.minimumControlHeight + 2 * Constants.chipShadowRoom).constraint
        }
        stack.addArrangedSubview(chipsScrollView)
    }

    /// The one-time note for a wallet that kept the network grouping, the empty search and "Search all networks".
    func setupNotes() {
        let noteStack = UIStackView(arrangedSubviews: [migrationLabel, dismissButton])
        noteStack.axis = .vertical
        noteStack.alignment = .leading
        noteStack.spacing = 2
        migrationCard.addSubview(noteStack)
        noteStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 16, bottom: 4, right: 16))
        }
        migrationRow.addSubview(migrationCard)
        migrationCard.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(4)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }
        stack.addArrangedSubview(migrationRow)

        for (row, content) in [(noResultsRow, noResultsLabel as UIView), (searchAllRow, searchAllButton)] {
            row.addSubview(content)
            content.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            }
            stack.addArrangedSubview(row)
        }
    }

    static func makeCaption() -> UILabel {
        let label = UILabel()
        label.textColor = FWSunlit.Palette.textSecondary
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    static func makeTextButton(identifier: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitleColor(FWSunlit.Palette.brandText, for: .normal)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.contentHorizontalAlignment = .leading
        button.accessibilityIdentifier = identifier
        button.snp.makeConstraints { $0.height.greaterThanOrEqualTo(Constants.minimumControlHeight) }
        return button
    }
}

// MARK: - UITextFieldDelegate

extension PortfolioDiscoveryView: UITextFieldDelegate {
    func textFieldDidBeginEditing(_: UITextField) {
        searchWell.controlFocused = true
        onSearchActiveChange?(true)
    }

    func textFieldDidEndEditing(_: UITextField) {
        searchWell.controlFocused = false
        deliverPendingSearch()
        onSearchActiveChange?(false)
    }

    func textFieldShouldReturn(_: UITextField) -> Bool {
        endSearchEditing()
        return true
    }
}
