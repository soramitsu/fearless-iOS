import UIKit
import SoraUI

final class SignerConfirmViewLayout: UIView {
    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let hintView = UIFactory.default.createHintView()

    let accountView = UIFactory.default.createAccountView(for: .options, filled: false)

    let moduleView = UIFactory.default.createTitleValueView()
    let callView = UIFactory.default.createTitleValueView()

    private(set) var amountView: NetworkFeeView?

    let feeView = UIFactory.default.createNetworkFeeView()
    let confirmView = UIFactory.default.createNetworkFeeConfirmView()

    let extrinsicToggle: ActionTitleControl = {
        let control = ActionTitleControl()
        control.imageView.image = R.image.iconArrowUp()
        control.activationIconAngle = 0.0
        control.identityIconAngle = CGFloat.pi
        control.titleLabel.textColor = R.color.colorWhite()!
        control.titleLabel.font = .p1Paragraph
        control.layoutType = .flexible
        return control
    }()

    let extrinsicView = UIFactory.default.createMultilinedTriangularedView(filled: false)

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()
        setupLayout()
        applyLocale()
    }

    var locale = Locale.current {
        didSet {
            applyLocale()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func insertAmountViewIfNeeded() {
        guard amountView == nil else {
            return
        }

        let amountView = UIFactory.default.createNetworkFeeView()
        amountView.titleLabel.text = R.string.localizable.walletSendAmountTitle(preferredLanguages: locale.rLanguages)

        contentView.stackView.insertArranged(view: amountView, before: feeView)
        amountView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        self.amountView = amountView
    }

    func removeAmountViewIfNeeded() {
        guard let amountView = amountView else {
            return
        }

        contentView.stackView.removeArrangedSubview(amountView)
        amountView.removeFromSuperview()

        self.amountView = nil
    }

    private func applyLocale() {
        hintView.titleLabel.text = R.string.localizable.signerConfirmHint(preferredLanguages: locale.rLanguages)
        accountView.title = R.string.localizable.commonFrom(preferredLanguages: locale.rLanguages)
        moduleView.titleLabel.text = R.string.localizable.commonModule(preferredLanguages: locale.rLanguages)
        callView.titleLabel.text = R.string.localizable.commonCall(preferredLanguages: locale.rLanguages)

        amountView?.locale = locale
        amountView?.titleLabel.text = R.string.localizable.walletSendAmountTitle(preferredLanguages: locale.rLanguages)

        feeView.locale = locale

        confirmView.locale = locale
        confirmView.networkFeeView.titleLabel.text = R.string.localizable.walletTransferTotalTitle(
            preferredLanguages: locale.rLanguages
        )

        extrinsicToggle.titleLabel.text = R.string.localizable.commonTxRaw(preferredLanguages: locale.rLanguages)

        extrinsicView.titleLabel.text = R.string.localizable.commonTransaction(preferredLanguages: locale.rLanguages)
    }

    private func setupLayout() {
        addSubview(confirmView)
        confirmView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(confirmView.snp.top)
        }

        contentView.stackView.addArrangedSubview(hintView)
        hintView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        contentView.stackView.setCustomSpacing(16.0, after: hintView)

        contentView.stackView.addArrangedSubview(accountView)
        accountView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(52.0)
        }

        contentView.stackView.setCustomSpacing(16.0, after: accountView)

        contentView.stackView.addArrangedSubview(moduleView)
        moduleView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }

        contentView.stackView.addArrangedSubview(callView)
        callView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }

        contentView.stackView.addArrangedSubview(feeView)
        feeView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        contentView.stackView.addArrangedSubview(extrinsicToggle)
        extrinsicToggle.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(48)
        }

        contentView.stackView.addArrangedSubview(extrinsicView)
        extrinsicView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }
    }
}
