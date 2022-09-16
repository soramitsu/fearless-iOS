import UIKit

final class AddCustomNodeViewLayout: UIView {
    let navigationBar: BaseNavigationBar = {
        let navBar = BaseNavigationBar()
        navBar.set(.present)
        return navBar
    }()

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let nodeNameInputView = UIFactory.default.createCommonInputView()
    let nodeAddressInputView = UIFactory.default.createCommonInputView()
    let addNodeButton = TriangularedButton()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .black
        setupLayout()

        addNodeButton.applyEnabledStyle()

        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var locale = Locale.current {
        didSet {
            applyLocalization()
        }
    }

    private func applyLocalization() {
        nodeNameInputView.animatedInputField.title = R.string.localizable.networkInfoName(
            preferredLanguages: locale.rLanguages
        )

        nodeAddressInputView.animatedInputField.title = R.string.localizable.networkInfoAddress(
            preferredLanguages: locale.rLanguages
        )

        addNodeButton.imageWithTitleView?.title = R.string.localizable.addNodeButtonTitle(
            preferredLanguages: locale.rLanguages
        )

        navigationBar.setTitle(R.string.localizable.addNodeButtonTitle(
            preferredLanguages: locale.rLanguages
        ))
    }

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(addNodeButton)

        contentView.stackView.addArrangedSubview(nodeNameInputView)
        contentView.stackView.addArrangedSubview(nodeAddressInputView)

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        addNodeButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        contentView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(addNodeButton.snp.top).inset(UIConstants.bigOffset)
        }

        nodeNameInputView.snp.makeConstraints { make in
            make.width.equalToSuperview().inset(UIConstants.defaultOffset * 2)
            make.height.equalTo(UIConstants.actionHeight)
        }

        nodeAddressInputView.snp.makeConstraints { make in
            make.width.equalToSuperview().inset(UIConstants.defaultOffset * 2)
            make.height.equalTo(UIConstants.actionHeight)
        }

        contentView.stackView.setCustomSpacing(UIConstants.bigOffset, after: nodeNameInputView)
    }

    func handleKeyboard(frame: CGRect) {
        addNodeButton.snp.updateConstraints { make in
            make.bottom.equalTo(safeAreaLayoutGuide).inset(frame.height + UIConstants.bigOffset)
        }
    }
}
