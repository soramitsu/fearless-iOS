import UIKit

public enum SoramitsuButtonSize {
    case large
    case small
    case extraSmall

    var height: CGFloat {
        switch self {
        case .large: return 56
        case .small: return 40
        case .extraSmall: return 32
        }
    }

    var font: FontData {
        switch self {
        case .large, .small: return FontType.buttonM
        case .extraSmall: return FontType.textBoldS
        }
    }
}

public class SoramitsuBaseButtonConfiguration<Type: UIControl & Element, FinalType: AnyObject>: SoramitsuControlConfiguration<Type> {

	public enum Mode {
		case spring
		case sticky
		case custom
	}

	public let stater: SoramitsuStateDecorator<FinalType, SoramitsuControlState>

	public var mode: Mode = .sticky

	public var size: SoramitsuButtonSize = .large

	public override var isEnabled: Bool {
		didSet {
			owner?.isEnabled = isEnabled
			if isEnabled, stater.state == .disabled {
				let isPreviousValid = stater.previousState != .disabled && stater.previousState != .pressed
				let target: SoramitsuControlState = isPreviousValid ? stater.previousState : .default
				tryUpdate(to: target)
			}
			if !isEnabled, stater.state != .disabled {
				tryUpdate(to: .disabled)
			}
		}
	}

	public var canBecomeDeselectedHandler: (() -> Bool)?

	init(style: SoramitsuStyle,
		 stater: SoramitsuStateDecorator<FinalType, SoramitsuControlState>) {
		self.stater = stater
		super.init(style: style)
	}

	override func configureOwner() {
		super.configureOwner()

		owner?.accessibilityTraits = .button

		addHandler(for: .touchDown, handler: { [weak self] in self?.buttonDidTouchDown() })
		addHandler(for: .touchUpInside, handler: { [weak self] in self?.buttonDidTouchUp() })
		addHandler(for: .touchUpOutside, .touchCancel, handler: { [weak self] in self?.buttonDidCancelTouch() })
	}

	private func buttonDidTouchDown() {
		let state: SoramitsuControlState
		switch mode {
		case .spring, .sticky: state = .pressed
		case .custom: return
		}
		tryUpdate(to: state)
	}

	private func buttonDidTouchUp() {
		let state: SoramitsuControlState
		switch mode {
		case .spring: state = .default
		case .sticky: state = stater.previousState == .default ? .selected : .default
		case .custom: return
		}
		tryUpdate(to: state)
	}

	private func buttonDidCancelTouch() {
		stater.revertToPreviousState()
	}

	private func tryUpdate(to state: SoramitsuControlState) {
		let previous = stater.previousState
		let deselectDenied = !(canBecomeDeselectedHandler?() ?? true)
		if state == .default, previous == .selected, deselectDenied {
			stater.update(to: .selected)
			return
		}
		stater.update(to: state)
	}
}
