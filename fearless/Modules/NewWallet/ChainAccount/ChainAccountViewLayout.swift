import UIKit
import SoraUI

protocol ChainAccountViewDelegate: AnyObject {
    func selectNetworkDidTap()
}

final class ChainAccountViewLayout: UIView {
    enum LayoutConstants {
        static let actionsViewHeight: CGFloat = 60
        static let accessoryButtonSize: CGFloat = 32.0
        static let addressLabelWidth: CGFloat = 200
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

    let crossChainButton: VerticalContentButton = {
        let button = VerticalContentButton()
        button.setImage(R.image.crossChainIcon(), for: .normal)
        button.titleLabel?.font = .p2Paragraph
        button.isHidden = true
        return button
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

    let selectNetworkButton = SelectedNetworkButton()

    private let actionsContentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        return stackView
    }()

    private let separatorView: UIView = UIFactory.default.createSeparatorView()

    private let balanceInfoStackView = UIFactory.default.createVerticalStackView()

    let transferableBalanceView: TitleMultiValueView = {
        let view = UIFactory.default.createMultiView()
        view.titleLabel.font = R.font.soraRc0040417Bold(size: 12)
        return view
    }()

    let balanceLocksView: TitleMultiValueView = {
        let view = UIFactory.default.createMultiView()
        view.titleLabel.font = R.font.soraRc0040417Bold(size: 12)
        return view
    }()

    let infoButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(R.image.iconInfoGrayFilled(), for: .normal)
        return button
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

    override func didMoveToSuperview() {
        super.didMoveToSuperview()

        var view: UIView?

        if let superview = superview?.superview {
            view = superview
        } else {
            view = self
        }

        view?.insertSubview(backgroundImageView, at: 0)
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func bind(balanceViewModel: ChainAccountBalanceViewModel?) {
        balanceInfoStackView.isHidden = balanceViewModel == nil

        transferableBalanceView.bindBalance(viewModel: balanceViewModel?.transferrableValue.value(for: locale))
        balanceLocksView.bindBalance(viewModel: balanceViewModel?.lockedValue.value(for: locale))
        infoButton.isHidden = !(balanceViewModel?.hasLockedTokens == true)
    }

    func bind(viewModel: ChainAccountViewModel) {
        walletNameTitle.text = viewModel.walletName
        selectNetworkButton.set(text: viewModel.selectedChainName, image: viewModel.selectedChainIcon)

        buyButton.isHidden = !viewModel.buyButtonVisible
        polkaswapButton.isHidden = !viewModel.polkaswapButtonVisible
        crossChainButton.isHidden = !viewModel.xcmButtomVisible
        actionsView.isHidden = viewModel.mode == .simple
        optionsButton.isHidden = viewModel.mode == .simple
        switch viewModel.mode {
        case .simple:
            selectNetworkButton.set(text: R.string.localizable.chainSelectionAllNetworks(preferredLanguages: locale.rLanguages), image: nil)
            addressCopyableLabel.isHidden = true
        case .extended:
            selectNetworkButton.set(text: viewModel.selectedChainName, image: nil)
            if let address = viewModel.address {
                addressCopyableLabel.isHidden = false
                addressCopyableLabel.bind(title: address)
            } else {
                addressCopyableLabel.isHidden = true
            }
        }
    }
}

private extension ChainAccountViewLayout {
    func setupLayout() {
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
        }

        actionsView.addSubview(balanceInfoStackView)
        actionsView.addSubview(separatorView)
        actionsView.addSubview(actionsContentStackView)
        balanceInfoStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }
        separatorView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(1)
            make.top.equalTo(balanceInfoStackView.snp.bottom).offset(UIConstants.defaultOffset)
        }
        actionsContentStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(LayoutConstants.actionsViewHeight)
            make.top.equalTo(separatorView.snp.bottom).offset(UIConstants.defaultOffset)
        }

        balanceInfoStackView.addArrangedSubview(transferableBalanceView)
        balanceInfoStackView.addArrangedSubview(balanceLocksView)

        transferableBalanceView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.cellHeight)
            make.leading.trailing.equalToSuperview()
        }

        balanceLocksView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.cellHeight)
            make.leading.trailing.equalToSuperview()
        }

        actionsContentStackView.addArrangedSubview(sendButton)
        actionsContentStackView.addArrangedSubview(receiveButton)
        actionsContentStackView.addArrangedSubview(crossChainButton)
        actionsContentStackView.addArrangedSubview(buyButton)
        actionsContentStackView.addArrangedSubview(polkaswapButton)

        balanceLocksView.addSubview(infoButton)

        infoButton.snp.makeConstraints { make in
            make.leading.equalTo(balanceLocksView.titleLabel.snp.trailing).offset(UIConstants.defaultOffset)
            make.centerY.equalToSuperview()
        }
    }

    func setupNavigationViewLayout() {
        selectNetworkButton.isUserInteractionEnabled = false

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
        walletBalanceVStackView.distribution = .fill
        walletBalanceVStackView.addArrangedSubview(walletBalanceViewContainer)
        walletBalanceVStackView.addArrangedSubview(addressCopyableLabel)

        addressCopyableLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        addressCopyableLabel.snp.makeConstraints { make in
            make.width.equalTo(LayoutConstants.addressLabelWidth)
            make.height.equalTo(LayoutConstants.addressLabelHeight)
        }

        walletBalanceViewContainer.snp.makeConstraints { make in
            make.height.equalTo(LayoutConstants.balanceViewHeight)
        }

        contentView.setCustomSpacing(LayoutConstants.navigationBarSpacing, after: navigationBar)
        contentView.addArrangedSubview(walletBalanceVStackView)

        walletBalanceVStackView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(LayoutConstants.balanceStackMinHeight)
        }
    }

    func applyLocalization() {
        sendButton.setTitle(R.string.localizable.walletSendTitle(preferredLanguages: locale.rLanguages), for: .normal)
        receiveButton.setTitle(R.string.localizable.commonActionReceive(preferredLanguages: locale.rLanguages), for: .normal)
        buyButton.setTitle(R.string.localizable.walletAssetBuy(preferredLanguages: locale.rLanguages), for: .normal)
        polkaswapButton.setTitle(R.string.localizable.polkaswapConfirmationSwapStub(preferredLanguages: locale.rLanguages), for: .normal)
        transferableBalanceView.titleLabel.text = R.string.localizable.assetdetailsBalanceTransferable(preferredLanguages: locale.rLanguages)
        balanceLocksView.titleLabel.text = R.string.localizable.walletBalanceLocked(preferredLanguages: locale.rLanguages)
        crossChainButton.setTitle(R.string.localizable.xcmCrossChainButtonTitle(preferredLanguages: locale.rLanguages), for: .normal)
    }
}
