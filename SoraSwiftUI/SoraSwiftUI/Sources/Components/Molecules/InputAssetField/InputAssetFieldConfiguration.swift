import UIKit

public final class InputAssetFieldConfiguration<Type: InputAssetField>: SoramitsuControlConfiguration<Type> {
    public var state: InputFieldState = .default {
        didSet {
            updateView()
        }
    }

    public var assetImage: UIImage? {
        didSet {
            owner?.assetImageView.image = assetImage
        }
    }
    
    public var assetSymbol: String? {
        didSet {
            owner?.choiceButton.sora.attributedText = SoramitsuTextItem(text: assetSymbol ?? "",
                                                                        fontData: FontType.displayS,
                                                                        textColor: .fgPrimary,
                                                                        alignment: .left)
        }
    }
    
    public var assetArrow: UIImage? {
        didSet {
            owner?.choiceButton.sora.rightImage = assetArrow
        }
    }
    
    public var fullFiatText: String? {
        didSet {
            owner?.fullFiatAmountLabel.sora.text = fullFiatText
        }
    }

    public var text: String? {
        didSet {
            owner?.textField.sora.attributedText = SoramitsuTextItem(text: text ?? "",
                                                                     fontData: FontType.displayS,
                                                                     textColor: .fgPrimary,
                                                                     alignment: .right)
        }
    }
    
    public var inputedFiatAmountText: String? {
        didSet {
            owner?.inputedFiatAmountLabel.sora.text = inputedFiatAmountText
        }
    }

    private var textObservation: NSKeyValueObservation?

    init(style: SoramitsuStyle, state: InputFieldState) {
        self.state = state
        super.init(style: style)
    }

    public override func styleDidChange(options: UpdateOptions) {
        super.styleDidChange(options: options)

        if options.contains(.palette) {
            updateView()
        }
    }

    func updateView() {
        owner?.containerView.layer.borderColor = style.palette.color(state.borderColor).cgColor
        owner?.containerView.backgroundColor = style.palette.color(.bgSurface)
    }
}
