import UIKit

struct EmptyViewModel {
    let title: String
    let description: String
}

enum EmptyViewIconMode {
    case bigFilledShadow
    case smallFilled

    var iconSize: CGFloat {
        switch self {
        case .bigFilledShadow:
            return 80
        case .smallFilled:
            return 56
        }
    }
}

final class EmptyView: UIView {
    var contentAlignment = ContentAlignment(vertical: .center, horizontal: .center) {
        didSet {
            handleLayoutConfigurationChanges()
        }
    }

    var image: UIImage? {
        get {
            imageView.image
        }

        set {
            imageView.image = newValue

            setNeedsLayout()
        }
    }

    var title: String? {
        get {
            titleLabel.text
        }

        set {
            titleLabel.text = newValue

            setNeedsLayout()
        }
    }

    var text: String? {
        get {
            descriptionLabel.text
        }

        set {
            descriptionLabel.text = newValue

            setNeedsLayout()
        }
    }

    var iconMode: EmptyViewIconMode = .bigFilledShadow {
        didSet {
            handleLayoutConfigurationChanges()
        }
    }

    private enum LayoutConstants {
        static let imageSize = CGSize(width: 36, height: 32)
        static let imageBackgroundSizeSmall: CGFloat = 56
        static let imageBackgroundSizeBig: CGFloat = 80
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
        label.textColor = R.color.colorWhite()
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

        handleLayoutConfigurationChanges()
    }

    private func handleLayoutConfigurationChanges() {
        switch iconMode {
        case .bigFilledShadow:
            imageBackgroundView.shadowColor = R.color.colorOrange()!
            imageBackgroundView.backgroundColor = R.color.colorBlack19()!
        case .smallFilled:
            imageBackgroundView.shadowColor = .clear
            imageBackgroundView.backgroundColor = R.color.colorWhite4()
        }

        switch contentAlignment.vertical {
        case .center:
            imageBackgroundView.snp.remakeConstraints { make in
                make.centerX.equalToSuperview()
                make.centerY.equalToSuperview()
                make.size.equalTo(iconMode.iconSize)
            }
        case .top:
            imageBackgroundView.snp.remakeConstraints { make in
                make.centerX.equalToSuperview()
                make.top.equalToSuperview().offset(UIConstants.bigOffset)
                make.size.equalTo(iconMode.iconSize)
            }
        case .bottom:
            preconditionFailure("EmptyView doensn't support .bottom layout")
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
