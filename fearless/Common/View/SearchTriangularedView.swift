import UIKit
import SoraUI
import SSFUtils

final class SearchTriangularedView: UIView {
    enum LayoutConstants {
        static let iconSize: CGFloat = 32
        static let viewHeight: CGFloat = 64
        static let verticalOffset: CGFloat = 12
        static let clearButtonSize: CGFloat = 16
        static let pasteButtonSize: CGFloat = 76
    }

    var isValid = false

    var onPasteTapped: (() -> Void)?
    private let withPasteButton: Bool

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    private let backgroundView: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.strokeColor = R.color.colorWhite8()!
        view.highlightedStrokeColor = R.color.colorPink()!
        view.strokeWidth = 0.5
        view.shadowOpacity = 0
        return view
    }()

    private let addressImage: PolkadotIconView = {
        let view = PolkadotIconView()
        view.isHidden = true
        view.backgroundColor = .clear
        return view
    }()

    private let placeholderImage: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.addressPlaceholder()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let pasteButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyStackButtonStyle()
        button.imageWithTitleView?.iconImage = R.image.iconCopy()
        return button
    }()

    private let cleanButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.deleteGrey()?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.tintColor = R.color.colorWhite()
        button.isHidden = true
        return button
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        label.textColor = R.color.colorStrokeGray()
        return label
    }()

    let textField: UITextField = {
        let view = UITextField()
        view.tintColor = R.color.colorPink()
        view.font = .p1Paragraph
        view.textColor = R.color.colorWhite()
        view.returnKeyType = .done

        if let oldStyle = view.defaultTextAttributes[
            .paragraphStyle,
            default: NSParagraphStyle()
        ] as? NSParagraphStyle,
            let style: NSMutableParagraphStyle = oldStyle.mutableCopy() as? NSParagraphStyle as? NSMutableParagraphStyle {
            style.lineBreakMode = .byTruncatingMiddle
            view.defaultTextAttributes[.paragraphStyle] = style
        }
        return view
    }()

    init(withPasteButton: Bool = false) {
        self.withPasteButton = withPasteButton
        super.init(frame: .zero)

        setupLayout()

        cleanButton.addTarget(self, action: #selector(clean), for: .touchUpInside)
        pasteButton.addTarget(self, action: #selector(pasteTapped), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateState(icon: DrawableIcon?, clearButtonIsHidden: Bool? = nil) {
        if let text = textField.text, text.isNotEmpty {
            cleanButton.isHidden = false
            pasteButton.isHidden = true
        } else {
            cleanButton.isHidden = true
            pasteButton.isHidden = false
        }
        if let icon = icon {
            addressImage.bind(icon: icon)
            addressImage.isHidden = false
            placeholderImage.isHidden = true
        } else {
            addressImage.isHidden = true
            placeholderImage.isHidden = false
        }
        if let clearButtonIsHidden = clearButtonIsHidden {
            cleanButton.isHidden = clearButtonIsHidden
        }
    }

    func set(highlighted: Bool, animated: Bool) {
        backgroundView.set(highlighted: highlighted, animated: animated)
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(LayoutConstants.viewHeight)
        }

        addSubview(addressImage)
        addressImage.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(LayoutConstants.iconSize)
        }
        addSubview(placeholderImage)
        placeholderImage.snp.makeConstraints { make in
            make.edges.equalTo(addressImage)
        }

        let vStackView = UIFactory
            .default
            .createVerticalStackView(spacing: UIConstants.minimalOffset)
        addSubview(vStackView)
        vStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(LayoutConstants.verticalOffset)
            make.leading.equalTo(addressImage.snp.trailing).offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(LayoutConstants.verticalOffset)
        }
        vStackView.addArrangedSubview(titleLabel)
        vStackView.addArrangedSubview(textField)

        addSubview(cleanButton)
        cleanButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.width.equalTo(LayoutConstants.clearButtonSize)
            make.leading.equalTo(vStackView.snp.trailing).offset(UIConstants.defaultOffset)
        }

        if withPasteButton {
            addSubview(pasteButton)
            pasteButton.snp.makeConstraints { make in
                make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
                make.centerY.equalToSuperview()
            }
        }
    }

    private func applyLocalization() {
        pasteButton.imageWithTitleView?.title = R.string.localizable.commonPaste(
            preferredLanguages: locale.rLanguages
        ).uppercased()
    }

    @objc
    private func clean() {
        textField.text = nil
        _ = textField.delegate?.textFieldShouldClear?(textField)
        updateState(icon: nil)
    }

    @objc
    private func pasteTapped() {
        onPasteTapped?()
    }
}
