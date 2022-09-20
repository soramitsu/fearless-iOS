import Foundation
import UIKit

final class EducationStoriesSlideView: UIView, EducationSlideView {
    // MARK: - UI

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h1Title.dynamicSize(fromSize: 30)
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
        label.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .h4Title.dynamicSize(fromSize: 16)
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
        label.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return label
    }()

    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = image
        imageView.contentMode = imageViewContentMode
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return imageView
    }()

    // MARK: - Properties

    let title: String
    let descriptionTitle: String
    let image: UIImage?
    let imageViewContentMode: ContentMode

    // MARK: - Constructors

    init(
        title: String,
        descriptionTitle: String,
        image: UIImage?,
        imageViewContentMode: ContentMode
    ) {
        self.title = title
        self.descriptionTitle = descriptionTitle
        self.image = image
        self.imageViewContentMode = imageViewContentMode
        super.init(frame: .zero)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Private methods

    private func setupLayout() {
        let textStackView = UIFactory.default.createVerticalStackView(spacing: 16)
        addSubview(textStackView)
        textStackView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }

        titleLabel.text = title
        textStackView.addArrangedSubview(titleLabel)

        descriptionLabel.text = descriptionTitle
        textStackView.addArrangedSubview(descriptionLabel)

        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.top.equalTo(textStackView.snp.bottom).offset(40)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}
