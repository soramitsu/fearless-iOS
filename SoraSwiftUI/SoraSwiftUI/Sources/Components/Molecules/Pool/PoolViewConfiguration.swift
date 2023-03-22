import UIKit

public final class PoolViewConfiguration<Type: PoolView>: SoramitsuControlConfiguration<Type> {

    public var mode: WalletViewMode {
        didSet {
            updateView()
        }
    }

    public var isFavorite: Bool = false {
        didSet {
            owner?.favoriteButton.sora.image = isFavorite ? favoriteButtonImage : unfavoriteButtonImage
        }
    }

    public var firstPoolImage: UIImage? {
        didSet {
            owner?.firstCurrencyImageView.image = firstPoolImage
        }
    }

    public var secondPoolImage: UIImage? {
        didSet {
            owner?.secondCurrencyImageView.image = secondPoolImage
        }
    }

    public var rewardTokenImage: UIImage? {
        didSet {
            owner?.rewardImageView.image = rewardTokenImage
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
            owner?.subtitleLabel.sora.isHidden = subtitleText.isEmpty
        }
    }

    public var upAmountText: String = "" {
        didSet {
            owner?.amountUpLabel.sora.text = upAmountText
            owner?.amountUpLabel.sora.isHidden = upAmountText.isEmpty
        }
    }

    public var downAmountText: String = "" {
        didSet {
            owner?.amountDownLabel.sora.text = downAmountText
            owner?.amountDownLabel.sora.isHidden = downAmountText.isEmpty
        }
    }

    public var dragDropImage: UIImage? {
        didSet {
            owner?.dragDropImageView.image = dragDropImage
            owner?.dragDropImageView.isHidden = false
        }
    }

    public var favoriteButtonImage: UIImage?
    public var unfavoriteButtonImage: UIImage?
    public var unvisibilityButtonImage: UIImage?

    init(style: SoramitsuStyle, mode: WalletViewMode) {
        self.mode = mode
        super.init(style: style)
        updateView()
    }

    func updateView() {
        owner?.favoriteButton.sora.isHidden = mode == .view
        owner?.amountStackView.isHidden = mode == .edit
        owner?.actionsStackView.isHidden = mode == .view

        owner?.favoriteButton.sora.image = isFavorite ? favoriteButtonImage : unfavoriteButtonImage
        owner?.stackView.layoutMargins = mode.insets
        owner?.stackView.isUserInteractionEnabled = mode == .edit
        owner?.isUserInteractionEnabled = mode == .edit
    }

    public override func styleDidChange(options: UpdateOptions) {
        super.styleDidChange(options: options)

        if options.contains(.palette) {
            retrigger(self, \.titleText)
            retrigger(self, \.subtitleText)
            retrigger(self, \.upAmountText)
            retrigger(self, \.downAmountText)
        }
    }
}
