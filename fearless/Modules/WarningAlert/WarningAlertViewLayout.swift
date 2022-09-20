import UIKit

final class WarningAlertViewLayout: UIView {
    enum LayoutConstants {
        static let warningIconSize: CGFloat = 32
        static let closeButtonSize: CGFloat = 32
    }

    let contentView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.isLayoutMarginsRelativeArrangement = true
        view.spacing = UIConstants.bigOffset
        view.alignment = .leading
        view.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let titleContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    let closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(R.image.iconClose(), for: .normal)
        return button
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = .white
        label.textAlignment = .left
        return label
    }()

    let warningIconImageView: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()

    let textLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorTransparentText()
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .black

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.addArrangedSubview(titleContainer)
        titleContainer.addSubview(titleLabel)
        titleContainer.addSubview(closeButton)

        contentView.addArrangedSubview(warningIconImageView)
        contentView.addArrangedSubview(textLabel)
        contentView.addArrangedSubview(actionButton)

        titleContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        textLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        warningIconImageView.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.warningIconSize)
        }

        actionButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
        }

        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(LayoutConstants.closeButtonSize)
        }
    }

    func bind(viewModel: WarningAlertConfig) {
        titleLabel.text = viewModel.title
        textLabel.text = viewModel.text
        actionButton.imageWithTitleView?.title = viewModel.buttonTitle
        warningIconImageView.image = viewModel.iconImage
        closeButton.isHidden = viewModel.blocksUi
    }
}
