import SnapKit
import UIKit

/// A wallet page with the one list's own search field. The wallet header's search button focuses it, and the header
/// folds its balance card away while the field has the keyboard.
protocol WalletInlineSearchHosting: AnyObject {
    /// Called with true when the search field takes the keyboard and false when it lets it go.
    var onInlineSearchActiveChange: ((Bool) -> Void)? { get set }

    /// Brings the search field into view and gives it the keyboard. False when the page shows no field.
    func focusInlineSearch() -> Bool
}

/// A network chip: a raised-1 pill that is pressed in, with brand text, while its network is the chosen filter.
final class PortfolioNetworkChipButton: UIControl {
    let surface: FWNeuView = {
        let view = FWNeuView()
        view.isUserInteractionEnabled = false
        view.isInteractive = true
        view.shape = { UIBezierPath(roundedRect: $0, cornerRadius: $0.height / 2) }
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 1
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    let chipId: String

    init(chip: PortfolioNetworkChip, isMore: Bool) {
        chipId = chip.id
        super.init(frame: .zero)
        addSubview(surface)
        surface.snp.makeConstraints { $0.edges.equalToSuperview() }
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }
        // The chips row gives every chip its height; the width follows the title.
        snp.makeConstraints { $0.width.greaterThanOrEqualTo(44) }
        titleLabel.text = isMore ? chip.title + " \u{203A}" : chip.title
        isSelected = chip.selected
        isAccessibilityElement = true
        accessibilityLabel = chip.title
        accessibilityIdentifier = "portfolioNetwork:" + chip.id
        updateState()
        addTarget(self, action: #selector(touchDown), for: [.touchDown, .touchDragEnter])
        addTarget(
            self,
            action: #selector(touchUp),
            for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit]
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isSelected: Bool {
        didSet { updateState() }
    }

    func apply(font: UIFont) {
        titleLabel.font = font
        invalidateIntrinsicContentSize()
    }

    private func updateState() {
        surface.style = isSelected ? .inset : .raised1
        titleLabel.textColor = isSelected ? FWSunlit.Palette.brandText : FWSunlit.Palette.textSecondary
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }

    @objc private func touchDown() {
        surface.setPressed(true, animated: true)
        let scale = FWMotionPolicy.current().pressScale
        transform = CGAffineTransform(scaleX: scale, y: scale)
    }

    @objc private func touchUp() {
        surface.setPressed(false, animated: true)
        transform = .identity
    }
}
