import SnapKit
import UIKit

/// This card makes no balance claim while the initial subscriptions are loading. Sun-lit: a raised card
/// whose rim follows the home sun; Receive is the emissive primary action.
final class PortfolioEmptyWalletView: UIView {
    let titleLabel = UILabel()
    let messageLabel = UILabel()
    let receiveButton = PortfolioActionButton()
    let buyButton = PortfolioActionButton()
    let unavailableLabel = UILabel()
    var onReceive: (() -> Void)?
    var onBuy: (() -> Void)?
    private let surface: FWNeuView = {
        let view = FWNeuView()
        view.style = .raised
        view.isUserInteractionEnabled = false
        view.shape = { UIBezierPath(roundedRect: $0, cornerRadius: FWSunlit.Radius.card) }
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isHidden = true
        backgroundColor = .clear
        addSubview(surface)
        surface.snp.makeConstraints { $0.edges.equalToSuperview() }
        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            messageLabel,
            receiveButton,
            buyButton,
            unavailableLabel
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            receiveButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            buyButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        titleLabel.accessibilityTraits.insert(.header)
        for label in [titleLabel, messageLabel, unavailableLabel] {
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
            label.textColor = label === titleLabel ? FWSunlit.Palette.textPrimary : FWSunlit.Palette.textSecondary
            label.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        for button in [receiveButton, buyButton] {
            button.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        receiveButton.emphasis = .primary
        receiveButton.configuration?.baseForegroundColor = UIColor(named: "fwTextOnAccent")
        receiveButton.addTarget(self, action: #selector(receive), for: .touchUpInside)
        buyButton.addTarget(self, action: #selector(buy), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(visible: Bool, canReceive: Bool, canBuy: Bool, locale: Locale) {
        isHidden = !visible
        titleLabel.text = PortfolioStrings.text("portfolio.empty_ready", locale: locale)
        messageLabel.text = PortfolioStrings.text("portfolio.empty_fund", locale: locale)
        receiveButton.configuration?.title = PortfolioStrings.text("common.action.receive", locale: locale)
        buyButton.configuration?.title = PortfolioStrings.text("portfolio.buy", locale: locale)
        receiveButton.isEnabled = canReceive
        buyButton.isEnabled = canBuy
        unavailableLabel.isHidden = canReceive && canBuy
        unavailableLabel.text = PortfolioStrings.text(
            canReceive ? "portfolio.buy_unavailable" : "portfolio.funding_unavailable",
            locale: locale
        )
        updateFonts()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        surface.sunRim = FWSunAnchor.shared.sunRim(for: surface, fallback: FWRowSunlit.fallbackRim)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateFonts()
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if previous?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            updateFonts()
        }
    }

    private func updateFonts() {
        titleLabel.font = UIFont.preferredFont(forTextStyle: .title2, compatibleWith: traitCollection)
        for label in [messageLabel, unavailableLabel] {
            label.font = UIFont.preferredFont(
                forTextStyle: .body,
                compatibleWith: traitCollection
            )
        }
    }

    @objc private func receive() {
        if receiveButton.isEnabled {
            onReceive?()
        }
    }

    @objc private func buy() {
        if buyButton.isEnabled {
            onBuy?()
        }
    }
}
