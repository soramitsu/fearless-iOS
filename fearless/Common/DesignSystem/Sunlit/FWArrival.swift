import SoraFoundation
import SoraUI
import UIKit

/// Decides when tokens arrived (brand kit v3, "Launch, feel and sound", part 2): an asset's balance for an account grew
/// compared with a value the app already knew for that same account and asset.
///
/// Never on the first value seen (a new or imported wallet, a first sync, a newly added network), never from a price
/// change (it compares token amounts only) and never for a hidden asset. Unknown values never replace a known one.
/// Thread-safe: balance callbacks arrive on any queue.
final class FWArrivalDetector {
    private let lock = NSLock()
    private var known: [String: Decimal] = [:]

    /// A value seen without announcing it: cached balances, the first batch after a wallet opens.
    func seed(key: String, amount: Decimal?) {
        guard let amount else { return }
        lock.lock()
        defer { lock.unlock() }
        if known[key] == nil {
            known[key] = amount
        }
    }

    /// Records `amount` and says whether it is an arrival: it grew from a value already known for `key`.
    func observe(key: String, amount: Decimal?, hidden: @autoclosure () -> Bool) -> Bool {
        guard let amount else { return false }
        lock.lock()
        defer { lock.unlock() }
        let previous = known[key]
        known[key] = amount
        guard let previous, amount > previous else { return false }
        return !hidden()
    }

    /// Another wallet opened: its values are first values again.
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        known = [:]
    }

    /// The key of one account's balance of one asset in one wallet.
    static func key(walletId: String, assetKey: String) -> String {
        "\(walletId)|\(assetKey)"
    }
}

/// Plays an arrival: the receive sound and touch, a gold pulse on the balance card and the app's own banner.
protocol FWArrivalAnnouncing: AnyObject {
    func announce(symbol: String, locale: Locale)
}

final class FWArrivalAnnouncer: FWArrivalAnnouncing {
    static let shared = FWArrivalAnnouncer()
    /// Posted on the main queue for the balance card's pulse; `userInfo["symbol"]` is the asset's symbol.
    static let didAnnounce = Notification.Name("FWArrivalDidAnnounce")
    /// At most one effect in any 3 s.
    static let quietPeriod: TimeInterval = 3

    private let feedback: FWFeedbackPlaying
    private let canAnnounce: () -> Bool
    private let clock: () -> TimeInterval
    private let presentBanner: (ApplicationStatusAlertEvent) -> Void
    private var lastAnnounced: TimeInterval?

    init(
        feedback: FWFeedbackPlaying = FWFeedback.shared,
        canAnnounce: @escaping () -> Bool = {
            UIApplication.shared.applicationState == .active && !FWLaunchIgnite.isShowing
        },
        clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        presentBanner: @escaping (ApplicationStatusAlertEvent) -> Void = { event in
            SceneWindowFinder.statusPresentableWindow()?.presentStatus(with: event, animated: true)
        }
    ) {
        self.feedback = feedback
        self.canAnnounce = canAnnounce
        self.clock = clock
        self.presentBanner = presentBanner
    }

    /// Announces on the main queue when the app is in the foreground and no launch is showing; nothing plays from the
    /// background, and arrivals within the quiet period of the last one stay silent.
    func announce(symbol: String, locale: Locale) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.announce(symbol: symbol, locale: locale) }
            return
        }
        _ = announceNow(symbol: symbol, locale: locale)
    }

    /// The decision and effects, on the main queue. Returns whether anything played.
    func announceNow(symbol: String, locale: Locale) -> Bool {
        guard canAnnounce() else { return false }
        let now = clock()
        if let lastAnnounced, now - lastAnnounced < Self.quietPeriod { return false }
        lastAnnounced = now
        feedback.play(.receive)
        NotificationCenter.default.post(name: Self.didAnnounce, object: self, userInfo: ["symbol": symbol])
        presentBanner(FWTokensReceivedEvent(symbol: symbol, locale: locale))
        return true
    }
}

/// "DOT received": the app's own status banner for an arrival.
final class FWTokensReceivedEvent: ApplicationStatusAlertEvent {
    let symbol: String
    let locale: Locale

    init(symbol: String, locale: Locale) {
        self.symbol = symbol
        self.locale = locale
    }

    var autoDismissing: Bool { true }
    var backgroundColor: UIColor { FWSunlit.Palette.gradientEnd }
    var image: UIImage? { R.image.iconReceive() }
    var titleText: String { String(format: FWFeelText.string("fw.feedback.tokens_received", locale: locale), symbol) }
    var descriptionText: String { "" }
}

/// Strings of the kit v3 feel, looked up in the selected app language.
enum FWFeelText {
    static func string(_ key: String, locale: Locale) -> String {
        let bundle = [locale.identifier, locale.languageCode].compactMap { $0 }
            .lazy.compactMap { Bundle.main.path(forResource: $0, ofType: "lproj") }.first
            .flatMap(Bundle.init(path:))
        let english = Bundle.main.path(forResource: "en", ofType: "lproj").flatMap(Bundle.init(path:))
        let value = bundle?.localizedString(forKey: key, value: nil, table: "Localizable")
        if let value, value != key { return value }
        return english?.localizedString(forKey: key, value: nil, table: "Localizable") ?? key
    }
}

#if DEBUG
    /// Debug-only seams for walking the feel on a simulator without real funds:
    /// `xcrun simctl spawn <udid> notifyutil -p jp.co.soramitsu.fearless.debug.arrival` runs a synthetic balance
    /// through the arrival rule (a known 1.0 growing to 2.5) and announces it; `…debug.sendsuccess` shows the send
    /// success screen with its ignite, as after an accepted transfer.
    enum FWFeelDebugSeams {
        static let arrival = "jp.co.soramitsu.fearless.debug.arrival"
        static let sendSuccess = "jp.co.soramitsu.fearless.debug.sendsuccess"
        private static let detector = FWArrivalDetector()
        private static var installed = false

        static func install() {
            guard !installed else { return }
            installed = true
            let center = CFNotificationCenterGetDarwinNotifyCenter()
            for name in [arrival, sendSuccess] {
                CFNotificationCenterAddObserver(center, nil, { _, _, name, _, _ in
                    guard let name = name?.rawValue as String? else { return }
                    DispatchQueue.main.async { FWFeelDebugSeams.handle(name) }
                }, name as CFString, nil, .deliverImmediately)
            }
        }

        static func handle(_ name: String) {
            switch name {
            case arrival:
                let key = FWArrivalDetector.key(walletId: "debug", assetKey: "debug-dot")
                detector.reset()
                detector.seed(key: key, amount: 1)
                if detector.observe(key: key, amount: 2.5, hidden: false) {
                    FWArrivalAnnouncer.shared.announce(symbol: "DOT", locale: LocalizationManager.shared.selectedLocale)
                }
            case sendSuccess:
                guard let top = SceneWindowFinder.mainWindow()?.rootViewController?.topModalController,
                      let controller = AllDoneAssembly.configureModule(
                          chainAsset: nil,
                          hashString: "0x5f0d…debug",
                          celebration: .send
                      )?.view.controller else { return }
                controller.modalPresentationStyle = .custom
                controller.modalTransitioningFactory = ModalSheetBlurPresentationFactory(
                    configuration: ModalSheetPresentationConfiguration.fearlessBlur
                )
                top.present(controller, animated: true)
            default:
                break
            }
        }
    }

    private extension UIViewController {
        var topModalController: UIViewController {
            presentedViewController?.topModalController ?? self
        }
    }
#endif
