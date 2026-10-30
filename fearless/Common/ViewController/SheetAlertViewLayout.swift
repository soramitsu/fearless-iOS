import Foundation
import UIKit
import SoraFoundation

final class SheetAlertViewLayout: UIView {
    private enum Constants {
        static let cornerRadius: CGFloat = 20.0
        static let imageViewContainerSize: CGFloat = 80.0
        static let imageViewSize = CGSize(width: 48, height: 42)
        static let closeButton: CGFloat = 44.0
        static var popupWindowHeightRatio: CGFloat {
            let window = SceneWindowFinder.activeWindow()
            let topPadding = window?.safeAreaInsets.top ?? .zero
            let bottomPadding = window?.safeAreaInsets.bottom ?? .zero
            return (window?.frame.height ?? UIScreen.main.bounds.height * 0.7) - topPadding - bottomPadding
        }
    }

    var dismissAndHandle: ((@escaping () -> Void) -> Void)?

    private let viewModel: SheetAlertPresentableViewModel
    private var descriptionHeightConstraint: NSLayoutConstraint?

    let closeButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = R.color.colorSemiBlack()
        button.setImage(R.image.iconClose(), for: .normal)
        button.accessibilityLabel = R.string.localizable.commonClose(
            preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages
        )
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
    private let contentScrollView = UIScrollView()
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
        if viewModel.scrollableContent { setupScrollableLayout() } else { setupLayout() }
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
        if !viewModel.scrollableContent { descriptionLabelLayoutSubviews() }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateScrollableFonts()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateScrollableFonts()
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
        if traitCollection.userInterfaceIdiom == .pad {
            adaptiveDescriptionLabelLayoutSubviews()
            return
        }
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

    /// iPad windows resize while the alert is up: the message scrolls only when the
    /// window is too short for it, and returns inline when there is room again.
    private func adaptiveDescriptionLabelLayoutSubviews() {
        guard let text = descriptionLabel.text, bounds.width > 32, let container = superview else { return }
        let width = bounds.width - 2 * UIConstants.horizontalInset
        let naturalHeight = text.height(withConstrainedWidth: width, font: descriptionLabel.font)
        let safeHeight = container.bounds.inset(by: container.safeAreaInsets).height
        let margin = AdaptiveLayout.isRegularWidth(traitCollection) ? 2 * AdaptiveLayout.sheetMargin : 0
        let fixedViews = contentStackView.arrangedSubviews.filter {
            !$0.isHidden && $0 !== descriptionLabel && $0 !== scrollableView
        }
        let fixedHeight = fixedViews.reduce(CGFloat(76 + UIConstants.bigOffset)) { height, view in
            height + view.systemLayoutSizeFitting(
                CGSize(width: width, height: 0), withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            ).height + 24
        }
        let messageHeight = min(naturalHeight, max(40, safeHeight - margin - fixedHeight))
        if messageHeight < naturalHeight {
            scrollableView.isHidden = false
            if descriptionLabel.superview !== scrollableView.stackView {
                descriptionLabel.removeFromSuperview()
                scrollableView.stackView.addArrangedSubview(descriptionLabel)
            }
            if let constraint = descriptionHeightConstraint {
                if abs(constraint.constant - messageHeight) > 0.5 {
                    constraint.constant = messageHeight
                }
            } else {
                let constraint = scrollableView.heightAnchor.constraint(equalToConstant: messageHeight)
                constraint.isActive = true
                descriptionHeightConstraint = constraint
            }
        } else if descriptionLabel.superview !== contentStackView {
            descriptionHeightConstraint?.isActive = false
            descriptionHeightConstraint = nil
            descriptionLabel.removeFromSuperview()
            let index = contentStackView.arrangedSubviews.firstIndex(of: scrollableView) ?? 0
            contentStackView.insertArrangedSubview(descriptionLabel, at: index)
            descriptionLabel.snp.makeConstraints { make in make.leading.trailing.equalToSuperview() }
            contentStackView.setCustomSpacing(24, after: descriptionLabel)
            scrollableView.isHidden = true
        }
    }

    /// An iPad window can be shorter than an alert with many actions: its content
    /// then scrolls, and keeps its own height when there is room.
    private func setupScrollingContentStack() {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = false
        addSubview(scrollView)
        scrollView.addSubview(contentStackView)
        scrollView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(76)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).inset(UIConstants.bigOffset)
            make.height.equalTo(contentStackView).priority(.low)
        }
        contentStackView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }
    }

    private func bindActions(actions: [SheetAlertPresentableAction], actionAxis: NSLayoutConstraint.Axis) {
        actions.forEach { action in
            let button = createButton(with: action)
            actionsStackView.addArrangedSubview(button)
            if viewModel.scrollableContent {
                button.snp.makeConstraints { $0.leading.trailing.equalToSuperview() }
                return
            }
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
        if viewModel.scrollableContent {
            if button.wrappingLabel == nil { button.snp.removeConstraints() }
            button.configureWrappingTitle(
                locale: LocalizationManager.shared.selectedLocale, compatibleWith: traitCollection
            )
        }
        button.addAction { [unowned self] in
            action.beforeDismissal?()
            if action.handlerAfterDismissal, let dismissAndHandle = self.dismissAndHandle {
                dismissAndHandle { action.handler?() }
            } else {
                self.closeButton.sendActions(for: .touchUpInside)
                action.handler?()
            }
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
            // A card's handle sits inside its rounded top edge; iPhone sheets are unchanged.
            make.top.equalToSuperview().offset(UIDevice.current.userInterfaceIdiom == .pad ? 8 : 0)
            make.centerX.equalToSuperview()
        }

        if !viewModel.isInfo, viewModel.showsCloseButton {
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

        if UIDevice.current.userInterfaceIdiom == .pad {
            setupScrollingContentStack()
        } else {
            addSubview(contentStackView)
            contentStackView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(76)
                make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
                make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).inset(UIConstants.bigOffset)
            }
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

private extension SheetAlertViewLayout {
    func updateScrollableFonts() {
        guard viewModel.scrollableContent else { return }
        titleLabel.font = .legacySora(size: 18, weight: .bold, textStyle: .title3, compatibleWith: traitCollection)
        descriptionLabel.font = .legacySora(
            size: 16, weight: .regular, textStyle: .body, compatibleWith: traitCollection
        )
        for case let button as TriangularedButton in actionsStackView.arrangedSubviews {
            button.configureWrappingTitle(
                locale: LocalizationManager.shared.selectedLocale, compatibleWith: traitCollection
            )
        }
    }

    func setupScrollableLayout() {
        backgroundColor = R.color.colorBlack19()!
        layer.cornerRadius = Constants.cornerRadius
        clipsToBounds = true
        actionsStackView.axis = .vertical
        let indicator = UIFactory.default.createIndicatorView()
        addSubview(indicator)
        indicator.snp.makeConstraints {
            $0.size.equalTo(UIConstants.indicatorSize)
            $0.top.centerX.equalToSuperview()
        }
        if viewModel.showsCloseButton {
            addSubview(closeButton)
            closeButton.snp.makeConstraints {
                $0.top.trailing.equalToSuperview().inset(20)
                $0.size.equalTo(Constants.closeButton)
            }
        }
        addSubview(contentScrollView)
        contentScrollView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(76)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).inset(UIConstants.bigOffset)
        }
        contentScrollView.addSubview(contentStackView)
        contentStackView.snp.makeConstraints {
            $0.top.bottom.equalTo(contentScrollView.contentLayoutGuide)
            $0.leading.trailing.equalTo(contentScrollView.contentLayoutGuide).inset(UIConstants.horizontalInset)
            $0.width.equalTo(contentScrollView.frameLayoutGuide).offset(-2 * UIConstants.horizontalInset)
        }
        setupScrollableContent()
    }

    func setupScrollableContent() {
        imageViewContainer.backgroundColor = R.color.colorBlack()
        imageViewContainer.snp.makeConstraints { $0.size.equalTo(Constants.imageViewContainerSize) }
        imageViewContainer.addSubview(imageView)
        imageView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(Constants.imageViewSize)
        }
        for element in [imageViewContainer, titleLabel, descriptionLabel, actionsStackView] {
            contentStackView.addArrangedSubview(element)
            contentStackView.setCustomSpacing(24, after: element)
        }
        for element in [titleLabel, descriptionLabel, actionsStackView] {
            element.snp.makeConstraints { $0.leading.trailing.equalToSuperview() }
        }
    }
}
