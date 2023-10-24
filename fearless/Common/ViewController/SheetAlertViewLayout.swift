import Foundation
import UIKit

final class SheetAlertViewLayout: UIView {
    private enum Constants {
        static let cornerRadius: CGFloat = 20.0
        static let imageViewContainerSize: CGFloat = 80.0
        static let imageViewSize = CGSize(width: 48, height: 42)
        static let closeButton: CGFloat = 32.0
        static var popupWindowHeightRatio: CGFloat {
            let window = UIApplication.shared.windows.first
            let topPadding = window?.safeAreaInsets.top ?? .zero
            let bottomPadding = window?.safeAreaInsets.bottom ?? .zero
            return (window?.frame.height ?? UIScreen.main.bounds.height * 0.7) - topPadding - bottomPadding
        }
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

    private let actionsStackView: UIStackView = {
        let stack = UIStackView()
        stack.spacing = UIConstants.verticalInset
        return stack
    }()

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

    private let scrollableView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.isHidden = true
        return view
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    init(viewModel: SheetAlertPresentableViewModel) {
        self.viewModel = viewModel
        actionsStackView.axis = viewModel.actionAxis
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
        descriptionLabelLayoutSubviews()
    }

    private func bind(viewModel: SheetAlertPresentableViewModel) {
        titleLabel.text = viewModel.title
        descriptionLabel.text = viewModel.message
        imageView.image = viewModel.icon
        imageViewContainer.isHidden = viewModel.icon == nil

        bindActions(actions: viewModel.actions, actionAxis: viewModel.actionAxis)

        if let closeAction = viewModel.closeAction {
            let action = SheetAlertPresentableAction(
                title: closeAction
            )
            bindActions(actions: [action], actionAxis: viewModel.actionAxis)
        }
    }

    private func descriptionLabelLayoutSubviews() {
        guard let descriptionText = descriptionLabel.text else {
            return
        }
        let labelFullHeight = descriptionText.height(
            withConstrainedWidth: frame.width - UIConstants.horizontalInset * 2,
            font: viewModel.messageStyle?.font ?? descriptionLabel.font
        )
        let viewHeight = bounds.height - labelFullHeight

        if (labelFullHeight + viewHeight) >= Constants.popupWindowHeightRatio {
            scrollableView.isHidden = false
            descriptionLabel.removeFromSuperview()
            scrollableView.stackView.addArrangedSubview(descriptionLabel)
            scrollableView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(labelFullHeight / 2)
            }
            scrollableView.scrollView.flashScrollIndicators()
        }
    }

    private func bindActions(actions: [SheetAlertPresentableAction], actionAxis: NSLayoutConstraint.Axis) {
        actions.forEach { action in
            let button = createButton(with: action)
            actionsStackView.addArrangedSubview(button)
            switch actionAxis {
            case .horizontal:
                actionsStackView.distribution = .fillEqually
                button.snp.makeConstraints { make in
                    make.height.equalTo(UIConstants.actionHeight)
                }
            case .vertical:
                button.snp.makeConstraints { make in
                    make.height.equalTo(UIConstants.actionHeight)
                    make.leading.trailing.equalToSuperview()
                }
            @unknown default:
                preconditionFailure()
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

        if !viewModel.isInfo, viewModel.icon != nil {
            titleLabel.removeFromSuperview()
            contentStackView.addArrangedSubview(titleLabel)
            contentStackView.setCustomSpacing(24, after: titleLabel)
        }

        contentStackView.addArrangedSubview(descriptionLabel)
        contentStackView.setCustomSpacing(24, after: descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }

        contentStackView.addArrangedSubview(scrollableView)
        contentStackView.setCustomSpacing(24, after: scrollableView)
        scrollableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }

        if !viewModel.isInfo {
            contentStackView.addArrangedSubview(actionsStackView)
            actionsStackView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
            }
        }
    }
}
