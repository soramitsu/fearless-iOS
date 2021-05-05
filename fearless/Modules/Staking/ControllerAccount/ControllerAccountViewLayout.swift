import UIKit

final class ControllerAccountViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let stashAccountView = UIFactory.default.createAccountView()

    let controllerAccountView = UIFactory.default.createAccountView()

    let learnMoreView = LearnMoreView()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let separator = UIView()
        separator.backgroundColor = R.color.colorDarkGray()
        addSubview(separator)
        separator.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(1 / UIScreen.main.scale)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.equalTo(separator.snp.bottom)
            make.leading.bottom.trailing.equalToSuperview()
        }

        containerView.stackView.spacing = 16
        containerView.stackView.addArrangedSubview(stashAccountView)
        stashAccountView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(52.0)
        }

        containerView.stackView.addArrangedSubview(controllerAccountView)
        controllerAccountView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(52.0)
        }

        containerView.stackView.addArrangedSubview(learnMoreView)
        learnMoreView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            // make.height.equalTo(52.0)
        }

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
