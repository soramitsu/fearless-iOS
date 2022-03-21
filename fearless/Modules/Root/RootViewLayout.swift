import UIKit

class RootViewLayout: UIView {
    let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.backgroundImage()
        return imageView
    }()

    let fearlessLogoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.logo()
        return imageView
    }()

    let infoView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    let infoLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    func applyLocalization() {}

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(backgroundImageView)
        addSubview(fearlessLogoImageView)
        addSubview(infoView)

        infoView.addSubview(infoLabel)
        infoView.addSubview(actionButton)

        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        fearlessLogoImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        infoView.snp.makeConstraints { make in
            make.top.equalTo(fearlessLogoImageView.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.trailing.equalToSuperview()
        }

        infoLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        actionButton.snp.makeConstraints { make in
            make.top.equalTo(infoLabel.snp.bottom).offset(UIConstants.bigOffset)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(UIConstants.actionHeight)
            make.width.equalToSuperview().inset(UIConstants.horizontalInset * 2)
        }
    }

    func bind(viewModel: RootViewModel) {
        infoLabel.text = viewModel.infoText
        actionButton.imageWithTitleView?.title = viewModel.buttonTitle
    }
}
