import SnapKit
import UIKit

/// The sun-lit wallet home (redesign spec 2026-11-08): the page light, the hero card with the winged-sun
/// badge as the emissive light source, its sync arc, and the round Send, Receive, Buy and Swap actions.
final class WalletHomeSunlitParts {
    let background = FWSunlitBackgroundView()
    /// Kit v3: two soft drifting glows over the page, and the sunset sky under the balance.
    let aurora = FWAuroraView()
    let skyCard = FWSkyCardView()
    var arrivalObservation: NSObjectProtocol?

    let heroSurface: FWNeuView = {
        let view = FWNeuView()
        view.style = .raised
        view.sunRim = FWSunlit.Light.maxSunRim
        view.shape = { UIBezierPath(roundedRect: $0, cornerRadius: FWSunlit.Radius.card) }
        return view
    }()

    let sunBadge: FWSunBadgeView = {
        let view = FWSunBadgeView()
        view.isAccessibilityElement = false
        return view
    }()

    let sendButton = FWRoundActionButton(icon: R.image.iconSend())
    let receiveButton = FWRoundActionButton(icon: R.image.iconReceive())
    let buyButton = FWRoundActionButton(icon: R.image.iconBuy())
    let swapButton = FWRoundActionButton(icon: R.image.iconSwap())

    let actionsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .top
        stack.spacing = 8
        return stack
    }()

    /// Wallet identity beside the search and scan tools; stacked at accessibility text sizes.
    let topRow: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        return stack
    }()

    var syncTracker = FWSyncTracker()
    var offsetObservation: NSKeyValueObservation?

    var actionButtons: [FWRoundActionButton] {
        [sendButton, receiveButton, buyButton, swapButton]
    }

    init() {
        sendButton.emissive = true
        sendButton.sheen = true
        sendButton.accessibilityIdentifier = "walletHomeSend"
        receiveButton.accessibilityIdentifier = "walletHomeReceive"
        buyButton.accessibilityIdentifier = "walletHomeBuy"
        swapButton.accessibilityIdentifier = "walletHomeSwap"
        actionButtons.forEach(actionsStack.addArrangedSubview)
    }
}

extension WalletMainContainerViewLayout {
    var sunBadgeView: FWSunBadgeView {
        sunlit.sunBadge
    }

    var sendButton: FWRoundActionButton {
        sunlit.sendButton
    }

    var receiveButton: FWRoundActionButton {
        sunlit.receiveButton
    }

    var buyButton: FWRoundActionButton {
        sunlit.buyButton
    }

    var swapButton: FWRoundActionButton {
        sunlit.swapButton
    }

    func installSunlitPage() {
        backgroundColor = FWSunlit.Palette.background
        addSubview(sunlit.background)
        sunlit.background.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        addSubview(sunlit.aurora)
        sunlit.aurora.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        // Tokens arriving light the balance card in gold.
        sunlit.arrivalObservation = NotificationCenter.default.addObserver(
            forName: FWArrivalAnnouncer.didAnnounce, object: nil, queue: .main
        ) { [weak self] _ in
            self?.sunlit.skyCard.pulse()
        }
        sunlit.offsetObservation = headerScrollView.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
            self?.updateSunPosition()
        }
    }

    func setupActionsLayout() {
        contentView.setCustomSpacing(18, after: sunlit.heroSurface)
        contentView.addArrangedSubview(sunlit.actionsStack)
        sunlit.actionsStack.snp.makeConstraints { make in
            make.width.equalTo(contentView.snp.width).offset(-2.0 * FWSunlit.Spacing.gutter)
        }
    }

    func localizeActions() {
        let languages = locale.rLanguages
        let titles = [
            R.string.localizable.commonActionSend(preferredLanguages: languages),
            R.string.localizable.commonActionReceive(preferredLanguages: languages),
            R.string.localizable.walletAssetBuy(preferredLanguages: languages),
            R.string.localizable.polkaswapConfirmationSwapStub(preferredLanguages: languages)
        ]
        for (button, title) in zip(sunlit.actionButtons, titles) {
            button.configure(title: title, locale: locale)
        }
    }

    /// Wallet identity beside the search and scan tools; the wallet badge glows as a small sun.
    func arrangeTopRow(identity: UIStackView, title: UILabel) {
        title.textColor = FWSunlit.Palette.textPrimary
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let toolsRow = UIStackView(arrangedSubviews: [searchButton, scanQRButton])
        toolsRow.axis = .horizontal
        toolsRow.alignment = .center
        toolsRow.spacing = 10
        toolsRow.setContentCompressionResistancePriority(.required, for: .horizontal)
        sunlit.topRow.addArrangedSubview(identity)
        sunlit.topRow.addArrangedSubview(toolsRow)
        switchWalletButton.layer.shadowColor = FWSunlit.Palette.brand.cgColor
        switchWalletButton.layer.shadowOpacity = 0.45
        switchWalletButton.layer.shadowRadius = 8
        switchWalletButton.layer.shadowOffset = .zero
    }

    func updateTopRowAxis() {
        let accessible = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        sunlit.topRow.axis = accessible ? .vertical : .horizontal
        sunlit.topRow.alignment = accessible ? .leading : .center
        sunlit.actionsStack.axis = accessible ? .vertical : .horizontal
        sunlit.actionsStack.alignment = accessible ? .fill : .top
    }

    /// The page bounce and the rims of the surfaces below follow the hero sun as the header lays out or scrolls.
    func updateSunPosition() {
        let sun = sunlit.sunBadge
        guard sun.window != nil, sun.bounds.width > 0 else { return }
        let center = sun.convert(CGPoint(x: sun.bounds.midX, y: sun.bounds.midY), to: self)
        if sunlit.background.sunCenter != center {
            sunlit.background.sunCenter = center
        }
        FWSunAnchor.shared.update(sunView: sun)
        for button in sunlit.actionButtons {
            button.sunRim = FWSunAnchor.shared.sunRim(for: button.surface)
        }
        // The sky's sun sits behind the badge; the scrim is at full strength from the balance down.
        let card = sunlit.skyCard
        card.sunCenter = sun.convert(CGPoint(x: sun.bounds.midX, y: sun.bounds.midY), to: card)
        card.textTop = walletBalanceViewContainer.convert(CGPoint.zero, to: card).y
        card.drift = -headerScrollView.contentOffset.y * 0.12
    }

    /// The sunset sky fills the hero card, under the badge and the balance. Added (not inserted at index 0) so its
    /// layer sits above the surface's own paint layers; the balance stack is added after it.
    func installSkyCard() {
        sunlit.heroSurface.addSubview(sunlit.skyCard)
        sunlit.skyCard.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    /// Chain connection and catalog sync changes from the presenter.
    func apply(syncUpdate: WalletSyncUpdate) {
        switch syncUpdate {
        case let .catalog(running):
            sunlit.syncTracker.catalogSync(running: running)
        case .catalogFailed:
            sunlit.syncTracker.catalogFailure()
        case let .connection(chainId, connection):
            sunlit.syncTracker.connection(chainId, connection)
        }
        showSyncState()
    }

    /// The wallet total is loading (no balance yet) or loaded.
    func setBalanceLoading(_ loading: Bool) {
        guard sunlit.syncTracker.balanceLoading != loading else { return }
        sunlit.syncTracker.balance(loading: loading)
        showSyncState()
    }

    private func showSyncState() {
        let state = sunlit.syncTracker.state
        guard state != sunlit.sunBadge.syncState else { return }
        sunlit.sunBadge.setSyncState(state, animated: window != nil)
        if case .failed = state {
            sunlit.background.bounceIntensity = FWSunlit.Motion.syncFailedSunAlpha
        } else {
            sunlit.background.bounceIntensity = 1
        }
    }
}
