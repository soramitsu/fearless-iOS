import UIKit

final class SignerConnectViewLayout: UIView {
    let contentView = ScrollableContainerView()

    let appView: IconWithSubtitleView = {
        let view = IconWithSubtitleView()
        return view
    }()

    let accountView: DetailsTriangularedView = UIFactory.default.createAccountView(for: .options, filled: false)

    let statusView: StatusRowView = {
        let view = StatusRowView()
        return view
    }()

    let connectionInfoView: TitleValueView = {
        let view = TitleValueView()
        view.titleLabel.textColor = R.color.colorLightGray()
        view.valueLabel.textColor = R.color.colorWhite()
        return view
    }()

    var locale = Locale.current {
        didSet {
            applyLocale()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        applyLocale()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocale() {
        statusView.locale = locale

        connectionInfoView.titleLabel.text = R.string.localizable
            .signerConnectConnectedTo(preferredLanguages: locale.rLanguages)
        accountView.title = R.string.localizable.accountInfoTitle(preferredLanguages: locale.rLanguages)
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.bottom.leading.trailing.equalToSuperview()
        }

        contentView.stackView.addArrangedSubview(appView)
        appView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
        }

        contentView.stackView.setCustomSpacing(8.0, after: appView)

        contentView.stackView.addArrangedSubview(accountView)
        accountView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(52.0)
        }

        contentView.stackView.setCustomSpacing(16.0, after: accountView)

        contentView.stackView.addArrangedSubview(statusView)
        statusView.snp.makeConstraints { make in
            make.width.equalTo(self)
        }

        contentView.stackView.addArrangedSubview(connectionInfoView)
        connectionInfoView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }
    }
}
