import UIKit
import SoraUI

final class ChooseRecipientViewLayout: UIView {
    enum LayoutConstants {
        static let stackActionHeight: CGFloat = 32
        static let stackViewSpacing: CGFloat = 12
        static let bottomContainerHeight: CGFloat = 120
        static let searchViewHeight: CGFloat = 64
    }

    let navigationBar: BaseNavigationBar = {
        let view = BaseNavigationBar()
        view.backgroundColor = R.color.colorBlack19()
        view.backButton.setImage(R.image.iconBack(), for: .normal)
        return view
    }()

    private let navigationTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = .white
        return label
    }()

    let bottomContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    private let optionsStackView: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.distribution = .fillProportionally
        view.spacing = 12
        view.isUserInteractionEnabled = true
        return view
    }()

    let scanButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyStackButtonStyle()
        button.imageWithTitleView?.iconImage = R.image.iconScanQr()
        return button
    }()

    let historyButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyStackButtonStyle()
        button.imageWithTitleView?.iconImage = R.image.iconHistory()
        return button
    }()

    let pasteButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyStackButtonStyle()
        button.imageWithTitleView?.iconImage = R.image.iconCopy()
        return button
    }()

    let nextButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDisabledStyle()
        return button
    }()

    let scamWarningView = ScamWarningExpandableView()

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = R.color.colorBlack19()
        return view
    }()

    let searchView = SearchTriangularedView(frame: .zero)

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack19()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(scamInfo: ScamInfo?, assetName: String) {
        guard let scamInfo = scamInfo else {
            scamWarningView.isHidden = true
            return
        }
        scamWarningView.isHidden = false

        scamWarningView.bind(scamInfo: scamInfo, assetName: assetName)
    }

    private func setupLayout() {
        addSubview(navigationBar)
        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        navigationBar.setCenterViews([navigationTitleLabel])

        addSubview(searchView)
        searchView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(LayoutConstants.searchViewHeight)
        }

        let contentVStackView = UIFactory.default.createVerticalStackView()

        addSubview(contentVStackView)
        contentVStackView.snp.makeConstraints { make in
            make.top.equalTo(searchView.snp.bottom).offset(UIConstants.verticalInset)
            make.leading.trailing.bottom.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        scamWarningView.isHidden = true
        contentVStackView.addArrangedSubview(scamWarningView)
        contentVStackView.addArrangedSubview(tableView)

        addSubview(bottomContainer)
        bottomContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(UIConstants.bigOffset)
        }

        bottomContainer.addSubview(nextButton)
        nextButton.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(UIConstants.actionHeight)
        }

        optionsStackView.addArrangedSubview(scanButton)
        optionsStackView.addArrangedSubview(historyButton)
        optionsStackView.addArrangedSubview(pasteButton)

        bottomContainer.addSubview(optionsStackView)
        optionsStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(nextButton.snp.top).offset(-UIConstants.bigOffset)
            make.height.equalTo(LayoutConstants.stackActionHeight)
            make.top.equalToSuperview()
        }
    }

    private func applyLocalization() {
        scamWarningView.locale = locale

        searchView.textField.placeholder = R.string.localizable.searchTextfieldPlaceholder(
            preferredLanguages: locale.rLanguages
        )
        searchView.titleLabel.text = R.string.localizable.searchViewTitle(
            preferredLanguages: locale.rLanguages
        )
        navigationTitleLabel.text = R.string.localizable.chooseRecipientTitle(
            preferredLanguages: locale.rLanguages
        )
        nextButton.imageWithTitleView?.title = R.string.localizable.chooseRecipientNextButtonTitle(
            preferredLanguages: locale.rLanguages
        )

        scanButton.imageWithTitleView?.title = R.string.localizable.scanQrTitle(
            preferredLanguages: locale.rLanguages
        ).uppercased()

        historyButton.imageWithTitleView?.title = R.string.localizable.walletHistoryTitle_v190(
            preferredLanguages: locale.rLanguages
        ).uppercased()

        pasteButton.imageWithTitleView?.title = R.string.localizable.commonPaste(
            preferredLanguages: locale.rLanguages
        ).uppercased()
    }

    func bind(viewModel: ChooseRecipientViewModel) {
        nextButton.set(enabled: viewModel.isValid)
        searchView.updateState(icon: viewModel.icon)
    }
}
