import UIKit

final class FeatureUnavailableViewController: UIViewController {
    private let featureTitle: String
    private let message: String
    private let icon: UIImage?
    private let actionTitle: String?
    private let action: ((UIViewController) -> Void)?
    private let secondaryActionTitle: String?
    private let secondaryAction: ((UIViewController) -> Void)?

    init(
        title: String, message: String, icon: UIImage?,
        actionTitle: String? = nil, action: ((UIViewController) -> Void)? = nil,
        secondaryActionTitle: String? = nil, secondaryAction: ((UIViewController) -> Void)? = nil
    ) {
        featureTitle = title
        self.message = message
        self.icon = icon
        self.actionTitle = actionTitle
        self.action = action
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryAction = secondaryAction
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = R.color.colorBlack19()
        title = featureTitle

        let imageView = UIImageView(image: icon)
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = R.color.colorPolkaswapPink()

        let titleLabel = UILabel()
        titleLabel.font = .h4Title
        titleLabel.textColor = R.color.colorWhite()
        titleLabel.textAlignment = .center
        titleLabel.text = featureTitle
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true

        let messageLabel = UILabel()
        messageLabel.font = .p1Paragraph
        messageLabel.textColor = R.color.colorLightGray()
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.text = message
        messageLabel.adjustsFontForContentSizeCategory = true

        let stackView = UIStackView(arrangedSubviews: [imageView, titleLabel, messageLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = UIConstants.bigOffset

        for (index, item) in [(actionTitle, action), (secondaryActionTitle, secondaryAction)].enumerated() {
            guard let title = item.0, let handler = item.1 else { continue }
            let button = UIButton(type: .system)
            let label = UILabel()
            label.text = title
            label.font = .h4Title
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 0
            label.textAlignment = .center
            label.textColor = index == 0 ? .white : R.color.colorPink()
            label.setContentCompressionResistancePriority(.required, for: .vertical)
            label.isAccessibilityElement = false
            button.addSubview(label)
            label.snp.makeConstraints { make in make.edges.equalToSuperview().inset(UIEdgeInsets(top: 14, left: 20, bottom: 14, right: 20)) }
            button.isAccessibilityElement = true
            button.accessibilityLabel = title
            button.backgroundColor = index == 0 ? R.color.colorPink() : .clear
            button.layer.cornerRadius = 8
            button.accessibilityIdentifier = "unavailable.action.\(index)"
            button.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                handler(self)
            }, for: .touchUpInside)
            stackView.addArrangedSubview(button)
            button.snp.makeConstraints { make in
                make.height.greaterThanOrEqualTo(48)
                make.width.equalTo(stackView)
            }
        }

        let scrollView = UIScrollView()
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in make.edges.equalTo(view.safeAreaLayoutGuide) }
        let contentView = UIView()
        scrollView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
            make.height.greaterThanOrEqualTo(scrollView.frameLayoutGuide)
            make.height.equalTo(scrollView.frameLayoutGuide).priority(.low)
        }
        contentView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.greaterThanOrEqualToSuperview().offset(32)
            make.bottom.lessThanOrEqualToSuperview().inset(32)
            make.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(32)
        }
        imageView.snp.makeConstraints { make in
            make.size.equalTo(64)
        }
    }
}
