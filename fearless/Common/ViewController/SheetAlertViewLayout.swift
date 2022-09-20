import Foundation
import UIKit

final class SheetAlertViewLayout: UIView {
    private enum Constants {
        static let cornerRadius: CGFloat = 20.0
        static let imageViewContainerSize: CGFloat = 80.0
        static let imageViewSize = CGSize(width: 48, height: 42)
    }

    private let viewModel: SheetAlertPresentableViewModel

    let closeButton: UIButton = {
        let button = UIButton()
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

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconWarningBig()
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

    private func bind(viewModel: SheetAlertPresentableViewModel) {
        titleLabel.text = viewModel.title
        descriptionLabel.text = viewModel.subtitle

        bindActions(actions: viewModel.actions)
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

        descriptionLabel.font = viewModel.subtitleStyle?.font
        descriptionLabel.textColor = viewModel.subtitleStyle?.textColor
    }

    private func createButton(with action: SheetAlertPresentableAction) -> TriangularedButton {
        let button = action.style
        button.imageWithTitleView?.title = action.title
        button.actionHandler(controlEvents: .touchUpInside, forAction: { [weak self] in
            action.handler?() ?? self?.closeButton.sendActions(for: .touchUpInside)
        })
        return button
    }

    private func setupLayout() {
        backgroundColor = R.color.colorAlmostBlack()!
        layer.cornerRadius = Constants.cornerRadius
        clipsToBounds = true

        let indicator = UIFactory.default.createIndicatorView()
        addSubview(indicator)
        indicator.snp.makeConstraints { make in
            make.size.equalTo(UIConstants.indicatorSize)
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
        }

        addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().inset(20)
        }

        let imageViewContainer = UIView()
        imageViewContainer.backgroundColor = R.color.colorBlack()
        imageViewContainer.layer.cornerRadius = Constants.imageViewContainerSize / 2
        imageViewContainer.layer.shadowColor = R.color.colorOrange()!.cgColor
        imageViewContainer.layer.shadowRadius = 12
        imageViewContainer.layer.shadowOpacity = 0.5
        imageViewContainer.snp.makeConstraints { make in
            make.size.equalTo(80)
        }

        imageViewContainer.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-3)
            make.size.equalTo(Constants.imageViewSize)
        }

        addSubview(contentStackView)
        contentStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(76)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).inset(UIConstants.bigOffset)
        }

        contentStackView.addArrangedSubview(imageViewContainer)
        contentStackView.setCustomSpacing(24, after: imageViewContainer)
        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.setCustomSpacing(16, after: titleLabel)
        contentStackView.addArrangedSubview(descriptionLabel)
        contentStackView.setCustomSpacing(24, after: descriptionLabel)
        contentStackView.addArrangedSubview(actionsStackView)
        actionsStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }
    }
}
