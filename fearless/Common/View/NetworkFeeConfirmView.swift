import UIKit
import Foundation

final class NetworkFeeConfirmView: UIView {
    private let contentStackView = UIFactory.default.createVerticalStackView(spacing: 8)

    let tipView = NetworkFeeView()
    let networkFeeView = NetworkFeeView()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorAlmostBlack()
        applyLocalization()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocalization() {
        tipView.titleLabel.text = R.string.localizable.walletSendTipTitle(preferredLanguages: locale.rLanguages)
        networkFeeView.locale = locale
        actionButton.imageWithTitleView?.title = R.string.localizable
            .commonConfirm(preferredLanguages: locale.rLanguages)
    }

    private func setupLayout() {
        addSubview(contentStackView)
        contentStackView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }

        tipView.isHidden = true // by default, because this view is being used among other screens but send confirmatio
        contentStackView.addArrangedSubview(tipView)
        contentStackView.addArrangedSubview(networkFeeView)
        contentStackView.addArrangedSubview(actionButton)

        actionButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
