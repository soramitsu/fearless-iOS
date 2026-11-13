import Foundation
import SoraUI

enum PinViewConfigurator {
    static func defaultPinView() -> PinView {
        let pinView = PinView()
        pinView.mode = .securedInput
        pinView.characterFieldsView?.numberOfCharacters = 6
        pinView.securedCharacterFieldsView?.numberOfCharacters = 6
        pinView.characterFieldsView?.fieldStrokeWidth = 2
        pinView.securedCharacterFieldsView?.fieldSize = CGSize(width: 15, height: 15)
        pinView.characterFieldsView?.fieldSpacing = 24
        pinView.securedCharacterFieldsView?.fieldSpacing = 24
        pinView.numpadView?.shadowRadius = 36
        pinView.numpadView?.keyRadius = 36
        pinView.numpadView?.verticalSpacing = 15
        pinView.numpadView?.horizontalSpacing = 22
        pinView.numpadView?.backspaceIcon =
            R.image.pinBackspace()?.tinted(with: R.color.colorWhite()!)?.withRenderingMode(.automatic)
        pinView.numpadView?.fillColor = .clear
        pinView.numpadView?.highlightedFillColor = R.color.colorCellSelection()
        pinView.numpadView?.titleColor = R.color.colorWhite()
        pinView.numpadView?.highlightedTitleColor = UIColor(
            red: 255 / 255,
            green: 255 / 255,
            blue: 255 / 255,
            alpha: 0.5
        )
        pinView.numpadView?.titleFont = UIFont.legacySora(size: 25, weight: .regular)
        pinView.securedCharacterFieldsView?.strokeWidth = 2
        pinView.securedCharacterFieldsView?.fieldRadius = 6
        pinView.verticalSpacing = 79
        pinView.securedCharacterFieldsView?.fillColor = R.color.colorWhite()!
        pinView.securedCharacterFieldsView?.strokeColor = R.color.colorWhite()!
        pinView.numpadView?.shadowOpacity = 0
        pinView.numpadView?.shadowRadius = 0
        pinView.numpadView?.shadowOffset = CGSize(width: 0, height: 1)
        pinView.numpadView?.shadowColor = UIColor(
            red: 47 / 255,
            green: 128 / 255,
            blue: 124 / 255,
            alpha: 0.3
        )
        pinView.numpadView?.supportsAccessoryControl = true
        return pinView
    }

    static let biometryKeyAccessibilityId = "PinBiometryKeyAccessibilityId"
}

extension PinView {
    /// Digit and backspace keys follow `enabled`. The biometric key stays usable: a trusted face or finger is still
    /// accepted during a PIN lockout, which only limits PIN guesses.
    func setPinEntryEnabled(_ enabled: Bool) {
        guard let numpad = numpadView else { return }
        numpad.setupAccessory(accessibilityId: PinViewConfigurator.biometryKeyAccessibilityId)
        for key in numpad.subviews.compactMap({ $0 as? UIControl })
            where key.accessibilityIdentifier != PinViewConfigurator.biometryKeyAccessibilityId {
            key.isEnabled = enabled
        }
        if !enabled {
            reset(shouldAnimateError: false)
        }
    }
}

/// Counts a PIN lockout down on screen with the monotonic clock, so changing the device clock cannot shorten it.
/// `onChange` receives the seconds left each second, then nil once when the lockout ends.
final class PinLockoutCountdown {
    private let clock: () -> TimeInterval
    private let onChange: (TimeInterval?) -> Void
    private var end: TimeInterval?
    private var timer: Timer?

    init(
        clock: @escaping () -> TimeInterval = MonotonicClock.uptime,
        onChange: @escaping (TimeInterval?) -> Void
    ) {
        self.clock = clock
        self.onChange = onChange
    }

    deinit {
        timer?.invalidate()
    }

    var isRunning: Bool {
        end != nil
    }

    func start(remaining: TimeInterval) {
        timer?.invalidate()
        end = clock() + remaining
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    func tick() {
        guard let end = end else { return }
        let left = end - clock()
        guard left > 0 else {
            timer?.invalidate()
            timer = nil
            self.end = nil
            onChange(nil)
            return
        }
        onChange(left)
    }

    /// Minutes and seconds, rounded up so the last second still reads 0:01.
    static func format(_ seconds: TimeInterval) -> String {
        let whole = max(0, Int(seconds.rounded(.up)))
        return String(format: "%ld:%02ld", whole / 60, whole % 60)
    }
}
