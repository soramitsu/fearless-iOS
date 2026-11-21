import Foundation
import UIKit
import SoraUI

final class SelectedNetworkButton: UIControl {
    private enum Constants {
        static let insets = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 8)
        static let imageVerticalPosition: CGFloat = 3
        static let imageWidth: CGFloat = 12
        static let imageHeight: CGFloat = 6
    }

    private let iconImageView = UIImageView()
    private var usesWrappingTypography = false
    private let container = UIFactory.default.createHorizontalStackView(spacing: 4)
    private let iconsRow = UIStackView()
    private var usesAccessibleLayout = false

    private var accessibleLayout: Bool {
        usesWrappingTypography && traitCollection.preferredContentSizeCategory.isAccessibilityCategory
    }

    private let title: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    private let dropTraingleImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.dropTriangle()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Opt-in typography and text-safe corners; other owners retain their legacy appearance.
    func applyTypography(_ font: UIFont) {
        title.font = font
        usesWrappingTypography = true
        updateArrangement()
        setNeedsLayout()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateArrangement()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // A tall multiline capsule would clip the title's first and last lines. Keep
        // the ordinary 44-point control's curvature while allowing its height to grow.
        let normalRadius = usesWrappingTypography ? min(22, bounds.height / 2) : bounds.height / 2
        layer.cornerRadius = accessibleLayout ? 8 : normalRadius
        clipsToBounds = true
    }

    func set(text: String, image: ImageViewModelProtocol?) {
        title.text = text
        if let imageViewModel = image {
            imageViewModel.loadImage(on: iconImageView, targetSize: CGSize(width: 16, height: 16), animated: false)
        } else {
            iconImageView.image = nil
        }
    }

    func applySelectableStyle(_ selectable: Bool) {
        dropTraingleImageView.isHidden = !selectable
    }

    private func setup() {
        isAccessibilityElement = true
        accessibilityTraits = .button
        backgroundColor = R.color.colorWhite8()
        container.alignment = .center
        addSubview(container)
        container.addArrangedSubview(iconImageView)
        container.addArrangedSubview(title)
        container.addArrangedSubview(dropTraingleImageView)

        for item in [container, iconImageView, title, dropTraingleImageView] {
            item.isUserInteractionEnabled = false
        }

        container.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(Constants.insets)
        }

        iconImageView.snp.makeConstraints { make in
            make.size.equalTo(16)
        }

        dropTraingleImageView.snp.makeConstraints { make in
            make.size.equalTo(10)
        }
    }

    /// Give large text the full control width; the small symbols share a separate row.
    private func updateArrangement() {
        guard usesAccessibleLayout != accessibleLayout else { return }
        usesAccessibleLayout = accessibleLayout
        container.arrangedSubviews.forEach { $0.removeFromSuperview() }
        iconsRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        container.axis = accessibleLayout ? .vertical : .horizontal
        container.alignment = accessibleLayout ? .fill : .center
        if accessibleLayout {
            iconsRow.axis = .horizontal
            iconsRow.alignment = .center
            [iconImageView, UIView(), dropTraingleImageView].forEach(iconsRow.addArrangedSubview)
            [iconsRow, title].forEach(container.addArrangedSubview)
        } else {
            [iconImageView, title, dropTraingleImageView].forEach(container.addArrangedSubview)
        }
    }
}
