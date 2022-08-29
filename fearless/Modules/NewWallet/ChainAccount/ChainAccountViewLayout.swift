import UIKit
import SoraUI

protocol ChainAccountViewDelegate: AnyObject {
    func selectNetworkDidTap()
}

final class ChainAccountViewLayout: UIView {
    enum LayoutConstants {
        static let actionsViewHeight: CGFloat = 80
        static let walletIconSize: CGFloat = 40.0
        static let accessoryButtonSize: CGFloat = 32.0
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
        return button
    }()

    private let walletNameTitle: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        return label
    }()

    // MARK: - Wallet balance view

    private let walletBalanceVStackView = UIFactory.default.createVerticalStackView(spacing: 4)
    let walletBalanceViewContainer = UIView()

    // MARK: - Address label

    private let addressCopyableLabel: CopyableLabelView = {
        let label = CopyableLabelView()
        return label
    }()

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

    let receiveContainer: BorderedContainerView = {
        let container = BorderedContainerView()
        container.borderType = [.left, .right]
        container.backgroundColor = .clear
        container.strokeWidth = 1.0
        container.strokeColor = R.color.colorDarkGray()!
        return container
    }()

    let chainOptionsContentView = UIView()

    let actionsView = TriangularedBlurView()

    let optionsButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(R.image.iconMore(), for: .normal)
        button.tintColor = .white
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
        buyButton.isEnabled = viewModel.chainAssetModel?.purchaseProviders?.first != nil
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
            make.size.equalTo(LayoutConstants.walletIconSize)
        }

        let walletInfoVStackView = UIFactory.default.createVerticalStackView(spacing: 6)
        walletInfoVStackView.alignment = .center
        walletInfoVStackView.distribution = .fill

        navigationBar.addSubview(walletInfoVStackView)
        walletInfoVStackView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.bottom.equalToSuperview()
            make.leading.greaterThanOrEqualTo(backButton.snp.trailing).priority(.low)
        }

        walletInfoVStackView.addArrangedSubview(walletNameTitle)
        walletInfoVStackView.addArrangedSubview(selectNetworkButton)
        selectNetworkButton.snp.makeConstraints { make in
            make.height.equalTo(22)
        }

        let accessoryButtonHStackView = UIFactory.default.createHorizontalStackView(spacing: 8)
        navigationBar.addSubview(accessoryButtonHStackView)
        accessoryButtonHStackView.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualTo(walletInfoVStackView.snp.trailing).priority(.low)
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
            make.width.lessThanOrEqualTo(135)
            make.height.equalTo(24)
        }

        walletBalanceViewContainer.snp.makeConstraints { make in
            make.height.equalTo(58)
        }

        walletBalanceVStackView.distribution = .fill
        walletBalanceVStackView.addArrangedSubview(walletBalanceViewContainer)
        walletBalanceVStackView.addArrangedSubview(addressCopyableLabel)

        contentView.setCustomSpacing(32, after: navigationBar)
        contentView.addArrangedSubview(walletBalanceVStackView)

        walletBalanceVStackView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(80)
        }
    }

    func applyLocalization() {
        sendButton.setTitle(R.string.localizable.walletSendTitle(preferredLanguages: locale.rLanguages), for: .normal)
        receiveButton.setTitle(R.string.localizable.walletAssetReceive(preferredLanguages: locale.rLanguages), for: .normal)
        buyButton.setTitle(R.string.localizable.walletAssetBuy(preferredLanguages: locale.rLanguages), for: .normal)
    }
}
