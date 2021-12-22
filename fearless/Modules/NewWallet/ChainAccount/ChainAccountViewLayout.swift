import UIKit
import SoraUI

final class ChainAccountViewLayout: UIView {
    enum LayoutConstants {
        static let actionsViewHeight: CGFloat = 80
    }

    let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.image = R.image.backgroundImage()
        return imageView
    }()

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let navigationBar = BaseNavigationBar()

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

    let actionsView = TriangularedBlurView()

    let assetInfoView = AssetInfoView()

    private let actionsContentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        return stackView
    }()

    let balanceView = AccountBalanceView()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        addSubview(backgroundImageView)
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(navigationBar)
        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        navigationBar.setCenterViews([assetInfoView])

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(navigationBar.snp.bottom)
        }

        contentView.stackView.addArrangedSubview(balanceView)
        balanceView.snp.makeConstraints { make in
            make.width.equalToSuperview().inset(UIConstants.bigOffset)
        }

        contentView.stackView.setCustomSpacing(UIConstants.defaultOffset, after: balanceView)

        contentView.stackView.addArrangedSubview(actionsView)
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

    func applyLocalization() {
        sendButton.setTitle(R.string.localizable.walletSendTitle(preferredLanguages: locale.rLanguages), for: .normal)
        receiveButton.setTitle(R.string.localizable.walletAssetReceive(preferredLanguages: locale.rLanguages), for: .normal)
        buyButton.setTitle(R.string.localizable.walletAssetBuy(preferredLanguages: locale.rLanguages), for: .normal)

        balanceView.totalView.titleLabel.text = R.string.localizable.assetdetailsBalanceTotal(preferredLanguages: locale.rLanguages)
        balanceView.transferableView.titleLabel.text = R.string.localizable.assetdetailsBalanceTransferable(preferredLanguages: locale.rLanguages)
        balanceView.lockedView.titleLabel.text = R.string.localizable.assetdetailsBalanceLocked(preferredLanguages: locale.rLanguages)
        balanceView.balanceViewTitleLabel.text = R.string.localizable.assetdetailsBalanceTitle(preferredLanguages: locale.rLanguages)
    }
}
