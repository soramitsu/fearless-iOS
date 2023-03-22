import UIKit

public enum HistoryTransactionViewType {
    case asset
    case pool
    case fiat
}

public final class HistoryTransactionViewConfiguration<Type: HistoryTransactionView>: SoramitsuControlConfiguration<Type> {

    public var firstHistoryTransactionImage: UIImage? {
        didSet {
            owner?.firstCurrencyImageView.image = firstHistoryTransactionImage
        }
    }

    public var secondHistoryTransactionImage: UIImage? {
        didSet {
            owner?.secondCurrencyImageView.image = secondHistoryTransactionImage
        }
    }
    
    public var transactionType: UIImage? {
        didSet {
            owner?.transactionTypeImageView.image = transactionType
        }
    }

    public var singleHistoryTransactionImage: UIImage? {
        didSet {
            owner?.oneCurrencyImageView.image = singleHistoryTransactionImage
        }
    }
    
    public var statusImage: UIImage? {
        didSet {
            owner?.statusImageView.image = statusImage
            owner?.statusImageView.sora.isHidden = statusImage == nil
        }
    }

    public var titleText: String = "" {
        didSet {
            owner?.titleLabel.sora.text = titleText
        }
    }

    public var subtitleText: String = "" {
        didSet {
            owner?.subtitleLabel.sora.text = subtitleText
        }
    }

    public var upAmountText: NSAttributedString? {
        didSet {
            owner?.amountUpLabel.sora.attributedText = upAmountText?.attributedString
        }
    }
    
    public var fiatText: String = "" {
        didSet {
            owner?.fiatLabel.sora.text = fiatText
        }
    }
    
    public var isNeedTwoTokens: Bool = false {
        didSet {
            owner?.secondCurrencyImageView.isHidden = !isNeedTwoTokens
            owner?.oneCurrencyImageView.isHidden = isNeedTwoTokens
            owner?.firstCurrencyHeightContstaint?.constant = isNeedTwoTokens ? 28 : 40
            owner?.layoutIfNeeded()
        }
    }

    private var type: HistoryTransactionViewType

    init(style: SoramitsuStyle, type: HistoryTransactionViewType) {
        self.type = type
        super.init(style: style)
        updateView()
    }

    func updateView() {
        owner?.secondCurrencyImageView.isHidden = type != .pool
    }

    public override func styleDidChange(options: UpdateOptions) {
        super.styleDidChange(options: options)

        if options.contains(.palette) {
            retrigger(self, \.titleText)
            retrigger(self, \.subtitleText)
            retrigger(self, \.upAmountText)
            retrigger(self, \.fiatText)
        }
    }
}
