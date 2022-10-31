import UIKit

struct EmptyViewModel {
    let title: String
    let description: String
}

final class EmptyView: UIView {
    private enum LayoutConstants {
        static let imageSize = CGSize(width: 36, height: 32)
        static let imageBackgroundSize: CGFloat = 56
        static let imageOffset: CGFloat = 10
    }

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconWarningBig()?.withRenderingMode(.alwaysTemplate)
        imageView.tintColor = R.color.colorWhite16()!
        return imageView
    }()

    private let imageBackgroundView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = LayoutConstants.imageBackgroundSize / 2
        view.backgroundColor = R.color.colorWhite8()!
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .h3Title
        label.textColor = .white
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
        addSubview(imageView)
        addSubview(titleLabel)
        addSubview(descriptionLabel)

        imageBackgroundView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide).offset(UIConstants.bigOffset)
            make.size.equalTo(LayoutConstants.imageBackgroundSize)
        }

        imageView.snp.makeConstraints { make in
            make.top.leading.equalTo(imageBackgroundView).offset(LayoutConstants.imageOffset)
            make.trailing.equalTo(imageBackgroundView).offset(-LayoutConstants.imageOffset)
            make.bottom.equalTo(imageBackgroundView).offset(-UIConstants.bigOffset)
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
