import UIKit

final class FeatureUnavailableViewController: UIViewController {
    private let featureTitle: String
    private let message: String
    private let icon: UIImage?

    init(title: String, message: String, icon: UIImage?) {
        featureTitle = title
        self.message = message
        self.icon = icon
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

        let messageLabel = UILabel()
        messageLabel.font = .p1Paragraph
        messageLabel.textColor = R.color.colorLightGray()
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.text = message

        let stackView = UIStackView(arrangedSubviews: [imageView, titleLabel, messageLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = UIConstants.bigOffset

        view.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(32)
        }
        imageView.snp.makeConstraints { make in
            make.size.equalTo(64)
        }
    }
}
