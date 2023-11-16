import UIKit
import SnapKit

final class NftSendViewLayout: UIView {
    enum LayoutConstants {
        static let verticalOffset: CGFloat = 25
        static let stackActionHeight: CGFloat = 32
        static let stackViewSpacing: CGFloat = 12
        static let bottomContainerHeight: CGFloat = 120
        static let stackSubviewHeight: CGFloat = 64
        static let optionsImageSize: CGFloat = 16
    }

    let navigationBar: BaseNavigationBar = {
        let view = BaseNavigationBar()
        view.backgroundColor = R.color.colorBlack19()
        return view
    }()

    let navigationTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 2
        return label
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
        button.isHidden = true
        return button
    }()

    let pasteButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyStackButtonStyle()
        button.imageWithTitleView?.iconImage = R.image.iconCopy()
        return button
    }()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDisabledStyle()
        return button
    }()

    let searchView = SearchTriangularedView()

    let feeView: NetworkFeeView = {
        let view = UIFactory.default.createNetworkFeeView()
        view.borderView.isHidden = true
        return view
    }()

    let scamWarningView: ScamWarningExpandableView = {
        let view = ScamWarningExpandableView()
        view.isHidden = true
        return view
    }()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    var keyboardAdoptableConstraint: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlack19()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        addSubview(navigationBar)
        addSubview(searchView)
        addSubview(scamWarningView)
        addSubview(feeView)
        addSubview(optionsStackView)
        addSubview(actionButton)

        optionsStackView.addArrangedSubview(scanButton)
        optionsStackView.addArrangedSubview(historyButton)
        optionsStackView.addArrangedSubview(pasteButton)

        navigationBar.setCenterViews([navigationTitleLabel])
        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        let viewOffset = -2.0 * UIConstants.horizontalInset

        searchView.snp.makeConstraints { make in
            make.height.equalTo(LayoutConstants.stackSubviewHeight)
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }
        feeView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.cellHeight)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(searchView.snp.bottom)
        }

        scamWarningView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(viewOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(feeView.snp.bottom)
        }

        actionButton.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
            keyboardAdoptableConstraint =
                make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset).constraint
        }

        optionsStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(actionButton.snp.top).offset(-UIConstants.bigOffset)
            make.height.equalTo(LayoutConstants.stackActionHeight)
        }
    }

    func applyLocalization() {
        feeView.locale = locale
        scamWarningView.locale = locale

        searchView.textField.attributedPlaceholder = NSAttributedString(
            string: R.string.localizable.searchTextfieldPlaceholder(
                preferredLanguages: locale.rLanguages
            ),
            attributes: [.foregroundColor: R.color.colorAlmostWhite()!]
        )
        searchView.titleLabel.text = R.string.localizable.searchViewTitle(
            preferredLanguages: locale.rLanguages
        )

        actionButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)

        scanButton.imageWithTitleView?.title = R.string.localizable.scanQrTitle(
            preferredLanguages: locale.rLanguages
        ).uppercased()

        historyButton.imageWithTitleView?.title = R.string.localizable.walletHistoryTitle_v190(
            preferredLanguages: locale.rLanguages
        ).uppercased()

        pasteButton.imageWithTitleView?.title = R.string.localizable.commonPaste(
            preferredLanguages: locale.rLanguages
        ).uppercased()

        navigationTitleLabel.text = R.string.localizable
            .chooseRecipientTitle(preferredLanguages: locale.rLanguages)
    }

    func bind(feeViewModel: BalanceViewModelProtocol?) {
        feeView.bind(viewModel: feeViewModel)
    }

    func bind(scamInfo: ScamInfo?) {
        guard let scamInfo = scamInfo else {
            scamWarningView.isHidden = true
            return
        }
        scamWarningView.isHidden = false

        scamWarningView.bind(scamInfo: scamInfo, assetName: "")
    }

    func bind(viewModel: RecipientViewModel) {
        searchView.textField.text = viewModel.address
        searchView.updateState(icon: viewModel.icon)
    }
}
