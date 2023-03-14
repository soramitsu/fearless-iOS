import UIKit
import SoraUI

protocol ChainAccountViewDelegate: AnyObject {
    func selectNetworkDidTap()
}

final class ChainAccountViewLayout: UIView {
    enum LayoutConstants {
        static let actionsViewHeight: CGFloat = 80
        static let accessoryButtonSize: CGFloat = 32.0
        static let addressLabelWidth: CGFloat = 135
        static let addressLabelHeight: CGFloat = 24
        static let balanceViewHeight: CGFloat = 58
        static let balanceViewWidth: CGFloat = 230
        static let balanceStackMinHeight: CGFloat = 80
        static let navigationBarSpacing: CGFloat = 32
    }

    weak var delegate: ChainAccountViewDelegate?

    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.image = R.image.backgroundImage()
        return imageView
    }()

    private let contentView: UIStackView = {
        let view = UIFactory.default.createVerticalStackView()
        view.alignment = .center
        return view
    }()

    // MARK: - Navigation view properties

    private let navigationBar = UIView()

    let backButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconBack(), for: .normal)
        button.backgroundColor = R.color.colorWhite8()
        button.layer.cornerRadius = LayoutConstants.accessoryButtonSize / 2
        return button
    }()

    private let walletNameTitle: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .h4Title
        return label
    }()

    // MARK: - Wallet balance view

    private let walletBalanceVStackView = UIFactory.default.createVerticalStackView(spacing: 4)
    let walletBalanceViewContainer = UIView()

    // MARK: - Address label

    let addressCopyableLabel = CopyableLabelView()

    let sendButton: VerticalContentButton = {
        let button = VerticalContentButton()
        button.setImage(R.image.iconSend(), for: .normal)
        button.titleLabel?.font = .p2Paragraph
        return button
    }()

    let receiveButton: VerticalContentButton = {
        let button = VerticalContentButton()
        button.setImage(R.image.iconReceive(), for: .normal)
        button.titleLabel?.font = .p2Paragraph
        return button
    }()

    let buyButton: VerticalContentButton = {
        let button = VerticalContentButton()
        button.setImage(R.image.iconBuy(), for: .normal)
        button.titleLabel?.font = .p2Paragraph
        return button
    }()

    let polkaswapButton: VerticalContentButton = {
        let button = VerticalContentButton()
        button.setImage(R.image.iconPolkaswap(), for: .normal)
        button.titleLabel?.font = .p2Paragraph
        return button
    }()

    let receiveContainer: BorderedContainerView = {
        let container = BorderedContainerView()
        container.backgroundColor = .clear
        container.strokeWidth = 1.0
        container.strokeColor = R.color.colorDarkGray()!
        return container
    }()

    let chainOptionsContentView = UIView()

    let actionsView: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = R.color.colorWhite4()!
        view.highlightedFillColor = R.color.colorWhite4()!
        view.shadowOpacity = 0
        return view
    }()

    let optionsButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(R.image.iconHorMore(), for: .normal)
        button.tintColor = R.color.colorWhite()
        button.backgroundColor = R.color.colorWhite8()
        button.layer.cornerRadius = LayoutConstants.accessoryButtonSize / 2
        return button
    }()

    let selectNetworkButton: SelectedNetworkButton = {
        let button = SelectedNetworkButton()
        button.titleLabel?.font = .p1Paragraph
        return button
    }()

    private let actionsContentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        return stackView
    }()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    var backButtonHandler: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: ChainAccountViewModel) {
        walletNameTitle.text = viewModel.walletName
        selectNetworkButton.setTitle(viewModel.selectedChainName, for: .normal)
        if let address = viewModel.address {
            addressCopyableLabel.isHidden = false
            addressCopyableLabel.bind(title: address)
        } else {
            addressCopyableLabel.isHidden = true
        }
        buyButton.isHidden = viewModel.chainAssetModel?.purchaseProviders?.first == nil
        polkaswapButton.isHidden = !(viewModel.chainAssetModel?.chain?.options?.contains(.polkaswap) == true)

        let borderType: BorderType = (buyButton.isHidden && polkaswapButton.isHidden) ? .left : [.left, .right]
        receiveContainer.borderType = borderType
    }
}

private extension ChainAccountViewLayout {
    func setupLayout() {
        addSubview(backgroundImageView)
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(5)
            make.leading.trailing.equalToSuperview()
        }

        setupNavigationViewLayout()
        setupBalanceLayout()

        contentView.setCustomSpacing(UIConstants.defaultOffset, after: walletBalanceVStackView)

        contentView.addArrangedSubview(actionsView)
        actionsView.snp.makeConstraints { make in
            make.width.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(LayoutConstants.actionsViewHeight)
        }

        actionsView.addSubview(actionsContentStackView)
        actionsContentStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        actionsContentStackView.addArrangedSubview(sendButton)
        actionsContentStackView.addArrangedSubview(receiveContainer)
        actionsContentStackView.addArrangedSubview(buyButton)
        actionsContentStackView.addArrangedSubview(polkaswapButton)

        receiveContainer.addSubview(receiveButton)
        receiveButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func setupNavigationViewLayout() {
        navigationBar.addSubview(backButton)
        backButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview()
            make.size.equalTo(LayoutConstants.accessoryButtonSize)
        }

        let walletInfoVStackView = UIFactory.default.createVerticalStackView(spacing: 6)
        walletInfoVStackView.alignment = .center
        walletInfoVStackView.distribution = .fill

        navigationBar.addSubview(walletInfoVStackView)
        walletInfoVStackView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.bottom.equalToSuperview()
            make.leading.greaterThanOrEqualTo(backButton.snp.trailing)
        }

        walletInfoVStackView.addArrangedSubview(walletNameTitle)
        walletInfoVStackView.addArrangedSubview(selectNetworkButton)
        selectNetworkButton.snp.makeConstraints { make in
            make.height.equalTo(22)
        }
        walletNameTitle.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.minimalOffset)
        }

        let accessoryButtonHStackView = UIFactory.default.createHorizontalStackView(spacing: 8)
        navigationBar.addSubview(accessoryButtonHStackView)
        accessoryButtonHStackView.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualTo(walletInfoVStackView.snp.trailing)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        accessoryButtonHStackView.addArrangedSubview(optionsButton)
        optionsButton.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.accessoryButtonSize)
        }

        contentView.addArrangedSubview(navigationBar)
        navigationBar.snp.makeConstraints { make in
            make.width.equalTo(contentView.snp.width).offset(-2.0 * UIConstants.horizontalInset)
        }
    }

    private func setupBalanceLayout() {
        addressCopyableLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        addressCopyableLabel.snp.makeConstraints { make in
            make.width.lessThanOrEqualTo(LayoutConstants.addressLabelWidth)
            make.height.equalTo(LayoutConstants.addressLabelHeight)
        }

        walletBalanceViewContainer.snp.makeConstraints { make in
            make.height.equalTo(LayoutConstants.balanceViewHeight)
            make.width.equalTo(LayoutConstants.balanceViewWidth)
        }

        walletBalanceVStackView.distribution = .fill
        walletBalanceVStackView.addArrangedSubview(walletBalanceViewContainer)
        walletBalanceVStackView.addArrangedSubview(addressCopyableLabel)

        contentView.setCustomSpacing(LayoutConstants.navigationBarSpacing, after: navigationBar)
        contentView.addArrangedSubview(walletBalanceVStackView)

        walletBalanceVStackView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(LayoutConstants.balanceStackMinHeight)
        }
    }

    func applyLocalization() {
        sendButton.setTitle(R.string.localizable.walletSendTitle(preferredLanguages: locale.rLanguages), for: .normal)
        receiveButton.setTitle(R.string.localizable.walletAssetReceive(preferredLanguages: locale.rLanguages), for: .normal)
        buyButton.setTitle(R.string.localizable.walletAssetBuy(preferredLanguages: locale.rLanguages), for: .normal)
        polkaswapButton.setTitle(R.string.localizable.polkaswapConfirmationSwapStub(preferredLanguages: locale.rLanguages), for: .normal)
    }
}
