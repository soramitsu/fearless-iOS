import UIKit

final class ControllerAccountConfirmationLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let stashAccountView: DetailsTriangularedView = {
        let accountView = UIFactory.default.createAccountView()
        accountView.strokeColor = R.color.colorGray()!
        accountView.highlightedStrokeColor = R.color.colorGray()!
        return accountView
    }()

    let controllerAccountView: DetailsTriangularedView = {
        let accountView = UIFactory.default.createAccountView()
        accountView.strokeColor = R.color.colorGray()!
        accountView.highlightedStrokeColor = R.color.colorGray()!
        return accountView
    }()

    let networkFeeFooterView: NetworkFeeFooterView = UIFactory.default.createNetworkFeeFooterView()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()!

        setupLayout()

        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
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

        addSubview(networkFeeFooterView)
        networkFeeFooterView.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
        }
    }

    private func applyLocalization() {
        networkFeeFooterView.locale = locale
    }
}
