import Foundation
import UIKit

final class CopyableLabelView: UIView {
    private enum Constants {
        static let minIconImageViewSize = CGSize(width: 16, height: 16)
    }

    var onСopied: (() -> Void)?

    private let label: UILabel = {
        let label = UILabel()
        label.lineBreakMode = .byTruncatingMiddle
        label.font = UIFont.p2Paragraph
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconCopy()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    /// "Copied" confirmation over the chip (sun-lit redesign); the address label itself never changes.
    private let confirmationLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = FWSunlit.Palette.success
        label.adjustsFontForContentSizeCategory = true
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.alpha = 0
        label.isAccessibilityElement = false
        return label
    }()

    private var confirmationID = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        gestureConfigure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Opt-in typography for rebuilt owners; existing consumers retain their legacy role.
    func applyTypography(_ font: UIFont) {
        label.font = font
        confirmationLabel.font = font
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = frame.height / 2
    }

    func bind(title: String) {
        label.text = title
        accessibilityValue = title
    }

    override func accessibilityActivate() -> Bool {
        handleTap()
        return true
    }

    private func gestureConfigure() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
    }

    @objc private func handleTap() {
        UIPasteboard.general.string = label.text
        onСopied?()
        showCopiedConfirmation()
    }

    /// The chip glows in the success colour with "Copied" for 900 ms (spec section 4).
    private func showCopiedConfirmation() {
        guard window != nil else { return }
        confirmationID += 1
        let id = confirmationID
        confirmationLabel.text = R.string.localizable.commonCopied()
        let style = FWMotionPolicy.current().style(for: .copied)
        let fade = style == .full(style.duration) ? FWSunlit.Motion.maxCrossfade : min(0.1, style.duration)
        layer.borderColor = FWSunlit.Palette.success.cgColor
        layer.shadowColor = FWSunlit.Palette.success.cgColor
        layer.shadowOffset = .zero
        layer.shadowRadius = 10
        layer.masksToBounds = false
        UIView.animate(withDuration: fade) {
            self.confirmationLabel.alpha = 1
            self.hStackViewAlpha = 0
            self.layer.borderWidth = 1
            self.layer.shadowOpacity = 0.6
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + FWSunlit.Motion.copied) { [weak self] in
            guard let self = self, self.confirmationID == id else { return }
            UIView.animate(withDuration: fade) {
                self.confirmationLabel.alpha = 0
                self.hStackViewAlpha = 1
                self.layer.borderWidth = 0
                self.layer.shadowOpacity = 0
            }
        }
    }

    private var hStackViewAlpha: CGFloat {
        get { label.superview?.alpha ?? 1 }
        set { label.superview?.alpha = newValue }
    }

    private func setupLayout() {
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = R.string.localizable.commonCopyAddress()
        backgroundColor = R.color.colorWhite8()

        let hStackView = UIFactory.default.createHorizontalStackView(spacing: 6)
        hStackView.distribution = .fillProportionally
        addSubview(hStackView)
        hStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.top.bottom.equalToSuperview().inset(UIConstants.minimalOffset)
        }

        iconImageView.snp.makeConstraints { make in
            make.size.greaterThanOrEqualTo(Constants.minIconImageViewSize)
        }

        hStackView.addArrangedSubview(label)
        hStackView.addArrangedSubview(iconImageView)

        addSubview(confirmationLabel)
        confirmationLabel.font = label.font
        confirmationLabel.snp.makeConstraints { make in
            make.edges.equalTo(hStackView)
        }

        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }
}
