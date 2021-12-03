import UIKit
import SoraFoundation

final class ChainAccountViewLayout: UIView {
    enum LayoutConstants {
        static let actionsViewHeight: CGFloat = 80
    }

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let sendButton: VerticalContentButton = {
        let button = VerticalContentButton()
        button.setImage(R.image.iconSend(), for: .normal)
        return button
    }()

    let receiveButton: VerticalContentButton = {
        let button = VerticalContentButton()
        button.setImage(R.image.iconReceive(), for: .normal)
        return button
    }()

    let buyButton: VerticalContentButton = {
        let button = VerticalContentButton()
        button.setImage(R.image.iconBuy(), for: .normal)
        return button
    }()

    let actionsView = TriangularedBlurView()

    private let actionsContentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        return stackView
    }()

    let balanceView = AccountBalanceView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.stackView.addArrangedSubview(balanceView)
        contentView.stackView.addArrangedSubview(actionsView)

        actionsView.addSubview(actionsContentStackView)

        actionsContentStackView.addArrangedSubview(sendButton)
        actionsContentStackView.addArrangedSubview(receiveButton)
        actionsContentStackView.addArrangedSubview(buyButton)
    }
}

extension ChainAccountViewLayout: Localizable {
    func applyLocalization() {
        sendButton.setTitle(R.string.localizable.walletSendTitle(preferredLanguages: selectedLocale.rLanguages), for: .normal)
        receiveButton.setTitle(R.string.localizable.walletAssetReceive(preferredLanguages: selectedLocale.rLanguages), for: .normal)
        buyButton.setTitle(R.string.localizable.walletAssetBuyWith(preferredLanguages: selectedLocale.rLanguages), for: .normal)
    }
}
