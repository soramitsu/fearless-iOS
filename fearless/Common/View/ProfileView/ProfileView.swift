import Foundation
import SoraUI
import FearlessUtils

protocol ProfileViewDelegate: class {
    func profileViewDidSelectContent(_ profileView: ProfileView)
    func profileViewDidSelectCopy(_ profileView: ProfileView)
}

@IBDesignable
final class ProfileView: UIView {
    private(set) var backgroundView: TriangularedView!
    private(set) var iconView: PolkadotIconView!
    private(set) var titleLabel: UILabel!
    private(set) var subtitleLabel: UILabel!
    private(set) var contentView: UIView!
    private(set) var contentControl: AlignableContentControl!
    private(set) var copyButton: RoundedButton!

    private var iconSizeConstraint: NSLayoutConstraint!
    private var titleLeading: NSLayoutConstraint!

    weak var delegate: ProfileViewDelegate?

    var horizontalSpacing: CGFloat = 8.0 {
        didSet {
            updateContentInsets()

            titleLeading.constant = horizontalSpacing

            setNeedsLayout()
        }
    }

    var iconRadius: CGFloat = 16.0 {
        didSet {
            iconSizeConstraint.constant = 2.0 * iconRadius
            setNeedsLayout()
        }
    }

    var contentInsets = UIEdgeInsets(top: 12.0, left: 12.0, bottom: 12.0, right: 16.0) {
        didSet {
            updateContentInsets()
            setNeedsLayout()
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        configure()
    }

    func bind(model: ProfileUserViewModelProtocol) {
        titleLabel.text = model.name
        subtitleLabel.text = model.details

        if let icon = model.icon {
            iconView.bind(icon: icon)
        }

        contentControl.invalidateLayout()
        setNeedsLayout()
    }

    private func configure() {
        self.backgroundColor = UIColor.clear

        configureBackgroundViewIfNeeded()
        configureCopyButtonIfNeeded()
        configureContentViewIfNeeded()
        configureContentControlIfNeeded()
    }

    private func configureBackgroundViewIfNeeded() {
        if backgroundView == nil {
            backgroundView = TriangularedView()
            backgroundView.translatesAutoresizingMaskIntoConstraints = false
            backgroundView?.isUserInteractionEnabled = false
            addSubview(backgroundView)

            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
            backgroundView.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
            backgroundView.topAnchor.constraint(equalTo: topAnchor).isActive = true
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        }
    }

    private func configureCopyButtonIfNeeded() {
        if copyButton == nil {
            copyButton = RoundedButton()
            copyButton.contentInsets = UIEdgeInsets(top: contentInsets.top,
                                                    left: horizontalSpacing,
                                                    bottom: contentInsets.bottom,
                                                    right: contentInsets.right + horizontalSpacing)

            copyButton.translatesAutoresizingMaskIntoConstraints = false
            copyButton.roundedBackgroundView?.fillColor = .clear
            copyButton.roundedBackgroundView?.highlightedFillColor = .clear
            copyButton.roundedBackgroundView?.shadowOpacity = 0.0
            copyButton.changesContentOpacityWhenHighlighted = true
            addSubview(copyButton)

            copyButton.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
            copyButton.setContentHuggingPriority(.defaultLow, for: .horizontal)

            copyButton.addTarget(self,
                                 action: #selector(didSelectCopy(_:)),
                                 for: .touchUpInside)

            copyButton.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
            copyButton.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        }
    }

    private func configureContentViewIfNeeded() {
        if contentView == nil {
            contentView = UIView()
            contentView.isUserInteractionEnabled = false

            iconView = PolkadotIconView()
            iconView.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(iconView)

            iconView.setContentHuggingPriority(.defaultLow, for: .horizontal)
            iconView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true

            iconSizeConstraint = iconView.widthAnchor.constraint(equalToConstant: 2.0 * iconRadius)
            iconSizeConstraint.isActive = true

            iconView.heightAnchor.constraint(equalTo: iconView.widthAnchor).isActive = true

            titleLabel = UILabel()
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(titleLabel)

            titleLeading = titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor,
                                                               constant: horizontalSpacing)
            titleLeading.isActive = true

            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true

            subtitleLabel = UILabel()
            subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(subtitleLabel)

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor).isActive = true
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true
            subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true

            titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
    }

    private func configureContentControlIfNeeded() {
        if contentControl == nil {
            contentControl = AlignableContentControl()
            addSubview(contentControl)

            contentControl.addTarget(self,
                                     action: #selector(didSelectContent(_:)),
                                     for: .touchUpInside)

            contentControl.translatesAutoresizingMaskIntoConstraints = false
            contentControl.contentView = contentView

            contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

            contentControl.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
            contentControl.topAnchor.constraint(equalTo: topAnchor).isActive = true
            contentControl.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
            contentControl.trailingAnchor.constraint(equalTo: copyButton.leadingAnchor).isActive = true

            contentControl.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
    }

    private func updateContentInsets() {
        contentControl.contentInsets = UIEdgeInsets(top: contentInsets.top,
                                                    left: contentInsets.left,
                                                    bottom: contentInsets.bottom,
                                                    right: 0.0)

        copyButton.contentInsets = UIEdgeInsets(top: contentInsets.top,
                                                left: horizontalSpacing,
                                                bottom: contentInsets.bottom,
                                                right: contentInsets.right + horizontalSpacing)
    }

    @objc private func didSelectContent(_ sender: Any?) {
        delegate?.profileViewDidSelectContent(self)
    }

    @objc private func didSelectCopy(_ sender: Any?) {
        delegate?.profileViewDidSelectCopy(self)
    }
}
