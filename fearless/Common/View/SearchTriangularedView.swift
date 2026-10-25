import UIKit
import SoraUI
import SSFUtils
import SnapKit

final class SearchTriangularedView: UIView {
    enum LayoutConstants {
        static let iconSize: CGFloat = 32
        static let viewHeight: CGFloat = 64
        static let verticalOffset: CGFloat = 12
        static let clearButtonSize: CGFloat = 16
        static let pasteButtonSize: CGFloat = 76
    }

    private var sendPresentation = false
    private var sendPlaceholderBottom: Constraint?
    let sendPlaceholderLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textColor = R.color.colorAlmostWhite()
        label.isUserInteractionEnabled = false
        label.isAccessibilityElement = false
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

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

    let accountScoreView = AccountScoreView()

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

    func bind(accountScoreViewModel: AccountScoreViewModel?) {
        textField.text = accountScoreViewModel?.address
        accountScoreView.bind(viewModel: accountScoreViewModel)
        refreshSendPlaceholder()
    }

    func updateState(icon: DrawableIcon?, clearButtonIsHidden: Bool? = nil) {
        refreshSendPlaceholder()
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

        vStackView.addArrangedSubview(titleLabel)

        let hStackView = UIFactory.default.createHorizontalStackView(spacing: 4)
        vStackView.addArrangedSubview(hStackView)

        hStackView.addArrangedSubview(textField)
        hStackView.addArrangedSubview(accountScoreView)

        accountScoreView.snp.makeConstraints { make in
            make.width.equalTo(32)
        }

        vStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(LayoutConstants.verticalOffset)
            make.leading.equalTo(addressImage.snp.trailing).offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(LayoutConstants.verticalOffset)
        }

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

extension SearchTriangularedView {
    func configureSendPresentation(locale: Locale, traits: UITraitCollection) {
        if !sendPresentation, let labels = titleLabel.superview {
            sendPresentation = true
            setupSendPlaceholder()
            backgroundView.snp.remakeConstraints { $0.edges.equalToSuperview() }
            addressImage.snp.removeConstraints()
            cleanButton.snp.removeConstraints()
            pasteButton.snp.removeConstraints()
            let icon = UIView()
            icon.addSubview(addressImage)
            addressImage.snp.makeConstraints { $0.edges.equalToSuperview() }
            icon.addSubview(placeholderImage)
            placeholderImage.snp.remakeConstraints { $0.edges.equalToSuperview() }
            icon.snp.makeConstraints { $0.size.equalTo(32) }
            let row = UIStackView(arrangedSubviews: [icon, UIView(), pasteButton, cleanButton])
            row.alignment = .center
            row.spacing = 8
            addSubview(row)
            row.snp.makeConstraints { make in
                make.leading.trailing.top.equalToSuperview().inset(12)
                make.height.greaterThanOrEqualTo(44)
            }
            cleanButton.snp.makeConstraints { $0.size.equalTo(44) }
            pasteButton.snp.makeConstraints { $0.width.equalTo(self).multipliedBy(0.6) }
            labels.snp.remakeConstraints { make in
                make.leading.trailing.bottom.equalToSuperview().inset(12)
                make.top.equalTo(row.snp.bottom).offset(8)
            }
        }
        self.locale = locale
        titleLabel.font = .fw(.bodyS, locale: locale, compatibleWith: traits)
        titleLabel.numberOfLines = 0
        textField.font = .fw(.monoM, locale: locale, compatibleWith: traits)
        textField.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
            make.height.greaterThanOrEqualTo(ceil(textField.font!.lineHeight) + 8)
        }
        pasteButton.configureWrappingTitle(locale: locale, compatibleWith: traits)
        sendPlaceholderLabel.font = .fw(.bodyM, locale: locale, compatibleWith: traits)
        refreshSendPlaceholder()
        setNeedsLayout()
    }

    private func setupSendPlaceholder() {
        guard let row = textField.superview as? UIStackView,
              let index = row.arrangedSubviews.firstIndex(of: textField) else { return }
        row.removeArrangedSubview(textField)
        textField.removeFromSuperview()
        let container = UIView()
        row.insertArrangedSubview(container, at: index)
        row.alignment = .center
        container.addSubview(textField)
        container.addSubview(sendPlaceholderLabel)
        sendPlaceholderLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(4)
            sendPlaceholderBottom = make.bottom.lessThanOrEqualToSuperview().inset(4).constraint
        }
        textField.addTarget(self, action: #selector(refreshSendPlaceholder), for: .editingChanged)
    }

    @objc private func refreshSendPlaceholder() {
        guard sendPresentation else { return }
        textField.attributedPlaceholder = nil
        textField.placeholder = nil
        sendPlaceholderLabel.text = R.string.localizable.searchTextfieldPlaceholder(
            preferredLanguages: locale.rLanguages
        )
        textField.accessibilityLabel = titleLabel.text
        textField.accessibilityHint = sendPlaceholderLabel.text
        let empty = textField.text?.isEmpty != false
        sendPlaceholderLabel.isHidden = !empty
        if empty { sendPlaceholderBottom?.activate() } else { sendPlaceholderBottom?.deactivate() }
        setNeedsLayout()
    }
}
