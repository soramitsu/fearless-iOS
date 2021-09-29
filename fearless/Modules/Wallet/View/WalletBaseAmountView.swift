import Foundation
import CommonWallet
import SoraUI

class WalletBaseAmountView: UIView {
    @IBOutlet private(set) var borderView: BorderedContainerView!
    @IBOutlet private(set) var fieldBackgroundView: TriangularedView!
    @IBOutlet private(set) var amountInputView: AmountInputView!
    @IBOutlet private(set) var contentView: UIView!

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupSubviews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        setupSubviews()
    }

    func setupSubviews() {
        _ = R.nib.walletAmountView(owner: self)
        addSubview(contentView)

        contentView.translatesAutoresizingMaskIntoConstraints = false

        contentView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        contentView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        contentView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        contentView.topAnchor.constraint(equalTo: topAnchor).isActive = true

        fieldBackgroundView.strokeColor = .clear
        fieldBackgroundView.highlightedStrokeColor = .clear

        amountInputView.triangularedBackgroundView?.strokeColor = R.color.colorStrokeGray()!
        amountInputView.triangularedBackgroundView?.highlightedStrokeColor = R.color.colorStrokeGray()!
        amountInputView.triangularedBackgroundView?.strokeWidth = 1.0
        amountInputView.triangularedBackgroundView?.fillColor = .clear
        amountInputView.triangularedBackgroundView?.highlightedFillColor = .clear

        amountInputView.titleLabel.textColor = R.color.colorLightGray()
        amountInputView.titleLabel.font = .p2Paragraph
        amountInputView.priceLabel.textColor = R.color.colorLightGray()
        amountInputView.priceLabel.font = .p2Paragraph
        amountInputView.symbolLabel.textColor = R.color.colorWhite()
        amountInputView.symbolLabel.font = .h4Title
        amountInputView.balanceLabel.textColor = R.color.colorLightGray()
        amountInputView.balanceLabel.font = .p2Paragraph
        amountInputView.textField.font = .h4Title
        amountInputView.textField.textColor = R.color.colorWhite()
        amountInputView.textField.tintColor = R.color.colorWhite()
        amountInputView.verticalSpacing = 2.0
        amountInputView.iconRadius = 12.0
        amountInputView.contentInsets = UIEdgeInsets(
            top: 8.0,
            left: UIConstants.horizontalInset,
            bottom: 8.0,
            right: UIConstants.horizontalInset
        )

        amountInputView.textField.attributedPlaceholder = NSAttributedString(
            string: "",
            attributes: [
                .foregroundColor: R.color.colorWhite()!.withAlphaComponent(0.5),
                .font: UIFont.h4Title
            ]
        )

        amountInputView.textField.keyboardType = .decimalPad
    }
}
