import UIKit

struct EmptyViewModel {
    let title: String
    let description: String
}

final class EmptyView: UIView {
    private enum LayoutConstants {
        static let imageSize = CGSize(width: 36, height: 32)
        static let imageBackgroundSize: CGFloat = 80
        static let imageOffset: CGFloat = 10
    }

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconWarningBig()
        return imageView
    }()

    private let imageBackgroundView: ShadowRoundedBackground = {
        let view = ShadowRoundedBackground()
        view.shadowColor = R.color.colorOrange()!
        view.backgroundColor = R.color.colorBlack19()!

        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .h3Title
        label.textColor = .white
        label.numberOfLines = 2
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .p0Paragraph
        label.textColor = R.color.colorStrokeGray()!
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: EmptyViewModel) {
        titleLabel.text = viewModel.title
        descriptionLabel.text = viewModel.description
    }

    private func setupLayout() {
        addSubview(imageBackgroundView)
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        imageBackgroundView.addSubview(imageView)

        imageBackgroundView.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.size.equalTo(LayoutConstants.imageBackgroundSize)
        }

        imageView.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.imageSize)
            make.center.equalTo(imageBackgroundView.snp.center)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().offset(-UIConstants.bigOffset)
            make.top.equalTo(imageBackgroundView.snp.bottom).offset(UIConstants.bigOffset)
        }

        descriptionLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().offset(-UIConstants.bigOffset)
            make.top.equalTo(titleLabel.snp.bottom).offset(UIConstants.bigOffset)
        }
    }
}
