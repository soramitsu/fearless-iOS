import UIKit

public enum InputFieldState {
    case `default`
    case focused
    case success
    case fail
    case disabled

    var isResultState: Bool {
        return self == .success || self == .fail
    }

    var borderColor: SoramitsuColor {
        switch self {
        case .`default`: return .bgSurfaceVariant
        case .focused: return .fgPrimary
        case .success: return .statusSuccess
        case .fail: return .statusError
        case .disabled: return .fgPrimary
        }
    }

    var descriptionColor: SoramitsuColor {
        switch self {
        case .`default`, .focused: return .fgSecondary
        case .success: return .statusSuccess
        case .fail: return .statusError
        case .disabled: return .fgPrimary
        }
    }
}

public final class InputFieldConfiguration<Type: InputField>: SoramitsuViewConfiguration<Type> {
    public var state: InputFieldState = .default {
        didSet(oldState) {
            if (oldState.isResultState && state == .focused) || (oldState.isResultState && state == .default) {
                state = oldState
            }
            updateView()
        }
    }

    public var leftImage: UIImage? {
        didSet {
            owner?.leftImageView.image = leftImage
            owner?.leftImageView.isHidden = leftImage == nil
        }
    }

    public var text: String? {
        set {
            owner?.textField.sora.text = newValue
            owner?.titleLabel.sora.isHidden = text?.isEmpty ?? true
        }
        get {
            owner?.textField.sora.text
        }
    }

    public var titleLabelText: String? {
        didSet {
            owner?.titleLabel.sora.text = titleLabelText
            owner?.titleLabel.sora.isHidden = owner?.textField.text?.isEmpty ?? true
        }
    }

    public var textFieldPlaceholder: String = "" {
        didSet {
            owner?.textField.sora.placeholder = textFieldPlaceholder
        }
    }

    public var buttonImage: UIImage? {
        didSet {
            owner?.button.sora.image = buttonImage
            owner?.button.sora.isHidden = buttonImage == nil
        }
    }
    
    public var buttonImageTintColor: SoramitsuColor? {
        didSet {
            owner?.button.sora.tintColor = buttonImageTintColor ?? .fgSecondary
        }
    }

    public var descriptionLabelText: String? {
        didSet {
            owner?.descriptionLabel.sora.text = descriptionLabelText
            owner?.descriptionLabel.sora.isHidden = descriptionLabelText == nil
        }
    }

    public var isEnabled: Bool = true {
        didSet {
            owner?.isUserInteractionEnabled = isEnabled
            state = isEnabled ? .default : .disabled
        }
    }

    public var keyboardType: UIKeyboardType = .default {
        didSet {
            owner?.textField.keyboardType = keyboardType
        }
    }

    public var textContentType: UITextContentType = .name {
        didSet {
            owner?.textField.textContentType = textContentType
        }
    }

    public func addHandler(for event: SoramitsuControlConfiguration<SoramitsuTextField>.Event, handler: (() -> Void)?) {
        owner?.textField.sora.addHandler(for: event, position: .last, handler: handler)
    }

    public func addHandler(for events: SoramitsuControlConfiguration<SoramitsuTextField>.Event..., handler: (() -> Void)?) {
        guard let handler = handler else { return }
        for event in events {
            owner?.textField.sora.addHandler(for: event, handler: handler)
        }
    }

    private var textObservation: NSKeyValueObservation?

    init(style: SoramitsuStyle, state: InputFieldState) {
        self.state = state
        super.init(style: style)
        updateView()
    }

    public override func styleDidChange(options: UpdateOptions) {
        super.styleDidChange(options: options)

        if options.contains(.palette) {
            updateView()
        }
    }

    func updateView() {
        if isEnabled {
            owner?.stackView.layer.borderColor = style.palette.color(state.borderColor).cgColor
            owner?.stackView.backgroundColor = style.palette.color(.bgSurface)
            owner?.descriptionLabel.sora.textColor = state.descriptionColor
        } else {
            owner?.stackView.layer.borderColor = style.palette.color(state.borderColor).withAlphaComponent(0.04).cgColor
            owner?.stackView.backgroundColor = style.palette.color(.fgPrimary).withAlphaComponent(0.04)
            owner?.descriptionLabel.sora.textColor = .custom(uiColor: style.palette.color(state.descriptionColor).withAlphaComponent(0.04))
        }
    }
}
