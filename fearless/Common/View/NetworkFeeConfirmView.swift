import UIKit
import Foundation

final class NetworkFeeConfirmView: UIView {
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
        addSubview(tipView) {
            $0.top.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(networkFeeView) {
            $0.top.equalTo(tipView.snp.bottom)
            $0.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(actionButton) {
            $0.height.equalTo(UIConstants.actionHeight)
            $0.top.equalTo(networkFeeView.snp.bottom).offset(UIConstants.horizontalInset)
            $0.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            $0.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }
    }
}
