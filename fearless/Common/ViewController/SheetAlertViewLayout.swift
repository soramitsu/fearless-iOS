import Foundation
import UIKit

final class SheetAlertViewLayout: UIView {
    private enum Constants {
        static let cornerRadius: CGFloat = 20.0
        static let imageViewContainerSize: CGFloat = 80.0
        static let imageViewSize = CGSize(width: 48, height: 42)
        static let closeButton: CGFloat = 32.0
    }

    private let viewModel: SheetAlertPresentableViewModel

    let closeButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = R.color.colorSemiBlack()
        button.setImage(R.image.iconClose(), for: .normal)
        return button
    }()

    private let contentStackView: UIStackView = {
        let stack = UIFactory.default.createVerticalStackView()
        stack.alignment = .center
        stack.distribution = .fill
        return stack
    }()

    private let actionsStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.verticalInset)
    private let imageViewContainer = UIView()
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        let image = viewModel.isInfo ? R.image.iconInfoGrayFill() : R.image.iconWarningBig()
        imageView.image = image
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    init(viewModel: SheetAlertPresentableViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
        applyStyle(viewModel: viewModel)
        setupLayout()
        bind(viewModel: viewModel)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        closeButton.rounded()
        imageViewContainer.rounded()
    }

    private func bind(viewModel: SheetAlertPresentableViewModel) {
        titleLabel.text = viewModel.title
        descriptionLabel.text = viewModel.message
        imageView.image = viewModel.icon
        imageViewContainer.isHidden = viewModel.icon == nil

        bindActions(actions: viewModel.actions)

        if let closeAction = viewModel.closeAction {
            let action = SheetAlertPresentableAction(
                title: closeAction
            )
            bindActions(actions: [action])
        }
    }

    private func bindActions(actions: [SheetAlertPresentableAction]) {
        actions.forEach { action in
            let button = createButton(with: action)
            actionsStackView.addArrangedSubview(button)
            button.snp.makeConstraints { make in
                make.height.equalTo(UIConstants.actionHeight)
                make.leading.trailing.equalToSuperview()
            }
        }
    }

    private func applyStyle(viewModel: SheetAlertPresentableViewModel) {
        titleLabel.font = viewModel.titleStyle.font
        titleLabel.textColor = viewModel.titleStyle.textColor

        descriptionLabel.font = viewModel.messageStyle?.font
        descriptionLabel.textColor = viewModel.messageStyle?.textColor
    }

    private func createButton(with action: SheetAlertPresentableAction) -> TriangularedButton {
        let button = action.button
        button.triangularedView?.fillColor = action.style.backgroundColor
        button.imageWithTitleView?.titleColor = action.style.titleColor

        button.imageWithTitleView?.title = action.title
        button.addAction { [unowned self] in
            self.closeButton.sendActions(for: .touchUpInside)
            action.handler?()
        }
        return button
    }

    private func setupLayout() {
        backgroundColor = R.color.colorBlack19()!
        layer.cornerRadius = Constants.cornerRadius
        clipsToBounds = true

        let indicator = UIFactory.default.createIndicatorView()
        addSubview(indicator)
        indicator.snp.makeConstraints { make in
            make.size.equalTo(UIConstants.indicatorSize)
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
        }

        if !viewModel.isInfo {
            addSubview(closeButton)
            closeButton.snp.makeConstraints { make in
                make.top.trailing.equalToSuperview().inset(20)
                make.size.equalTo(Constants.closeButton)
            }
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().inset(20)
        }

        let containerBackgroundColor = viewModel.isInfo ? R.color.colorWhite8() : R.color.colorBlack()
        imageViewContainer.backgroundColor = containerBackgroundColor
        if !viewModel.isInfo {
            imageViewContainer.layer.shadowColor = R.color.colorOrange()!.cgColor
            imageViewContainer.layer.shadowRadius = 12
            imageViewContainer.layer.shadowOpacity = 0.5
        }
        let imageViewContainerSize = viewModel.isInfo ? 56 : 80
        imageViewContainer.snp.makeConstraints { make in
            make.size.equalTo(imageViewContainerSize)
        }

        imageViewContainer.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-3)
            make.size.equalTo(Constants.imageViewSize)
        }
        if viewModel.isInfo {
            imageView.snp.remakeConstraints { make in
                make.center.equalToSuperview()
                make.size.equalTo(32)
            }
        }

        addSubview(contentStackView)
        contentStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(76)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).inset(UIConstants.bigOffset)
        }

        contentStackView.addArrangedSubview(imageViewContainer)
        contentStackView.setCustomSpacing(24, after: imageViewContainer)
        contentStackView.addArrangedSubview(descriptionLabel)
        contentStackView.setCustomSpacing(24, after: descriptionLabel)

        if !viewModel.isInfo {
            contentStackView.addArrangedSubview(actionsStackView)
            actionsStackView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
            }
        }
    }
}
