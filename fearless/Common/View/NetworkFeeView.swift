import UIKit
import SoraUI

final class NetworkFeeView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = UIFont.p1Paragraph
        return label
    }()

    let tokenLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = UIFont.p1Paragraph
        return label
    }()

    let borderView: BorderedContainerView = {
        let view = BorderedContainerView()
        view.backgroundColor = .clear
        view.borderType = .bottom
        view.strokeWidth = 1.0
        view.strokeColor = R.color.colorDarkGray()!
        return view
    }()

    let activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView()
        view.hidesWhenStopped = true
        view.style = .white
        return view
    }()

    private(set) var fiatLabel: UILabel?

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        applyLocalization()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocalization() {
        titleLabel.text = R.string.localizable.commonNetworkFee(preferredLanguages: locale.rLanguages)
    }

    private func setupLayout() {
        addSubview(borderView)
        borderView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(tokenLabel)
        tokenLabel.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8.0)
        }

        addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
        }
    }

    private func addFiatLabelIfNeeded() {
        guard fiatLabel == nil else {
            return
        }

        let fiatLabel = UILabel()
        fiatLabel.textColor = R.color.colorGray()
        fiatLabel.font = .p2Paragraph

        addSubview(fiatLabel)
        fiatLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.top.equalTo(self.snp.centerY)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8.0)
        }

        tokenLabel.snp.remakeConstraints { make in
            make.trailing.equalToSuperview()
            make.bottom.equalTo(self.snp.centerY)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8.0)
        }

        self.fiatLabel = fiatLabel
    }

    private func removeFiatLabelIfNeeded() {
        guard fiatLabel != nil else {
            return
        }

        fiatLabel?.removeFromSuperview()
        fiatLabel = nil

        tokenLabel.snp.remakeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8.0)
        }
    }

    func bind(viewModel: BalanceViewModelProtocol?) {
        if viewModel != nil {
            activityIndicator.stopAnimating()
        } else {
            activityIndicator.startAnimating()
        }

        tokenLabel.text = viewModel?.amount

        if let fiatAmount = viewModel?.price {
            addFiatLabelIfNeeded()
            fiatLabel?.text = fiatAmount
        } else {
            removeFiatLabelIfNeeded()
        }

        setNeedsLayout()
    }
}
