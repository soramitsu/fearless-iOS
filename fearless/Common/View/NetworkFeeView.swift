import UIKit
import SoraUI

final class NetworkFeeView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorStrokeGray()
        label.font = UIFont.p2Paragraph
        return label
    }()

    let tokenLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = UIFont.p2Paragraph
        return label
    }()

    let borderView: BorderedContainerView = {
        let view = BorderedContainerView()
        view.backgroundColor = .clear
        view.borderType = .none
        view.strokeWidth = 1.0
        view.strokeColor = R.color.colorStrokeGray()!
        return view
    }()

    let activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView()
        view.hidesWhenStopped = true
        view.style = .medium
        return view
    }()

    private(set) var fiatLabel: UILabel?
    private var presentationLocale: Locale?
    private var presentationTraits: UITraitCollection?

    func configureSendPresentation(locale: Locale, traits: UITraitCollection) {
        presentationLocale = locale
        presentationTraits = traits
        titleLabel.font = .fw(.bodyS, locale: locale, compatibleWith: traits)
        tokenLabel.font = .fw(.numberL, locale: locale, compatibleWith: traits)
        fiatLabel?.font = .fw(.numberM, locale: locale, compatibleWith: traits)
        [titleLabel, tokenLabel, fiatLabel].compactMap { $0 }.forEach {
            $0.numberOfLines = 0
            $0.lineBreakMode = .byCharWrapping
            $0.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        titleLabel.snp.remakeConstraints { $0.leading.trailing.top.equalToSuperview() }
        tokenLabel.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.height.greaterThanOrEqualTo(ceil(tokenLabel.font.lineHeight))
            if fiatLabel == nil { make.bottom.equalToSuperview() }
        }
        fiatLabel?.snp.remakeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(tokenLabel.snp.bottom).offset(6)
        }
        activityIndicator.snp.remakeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalTo(tokenLabel)
        }
        setNeedsLayout()
    }

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
        fiatLabel.textColor = R.color.colorStrokeGray()
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

        UIView.transition(
            with: tokenLabel,
            duration: 0.25,
            options: .transitionCrossDissolve,
            animations: { [weak self] in
                self?.tokenLabel.text = viewModel?.amount
            },
            completion: nil
        )

        if let fiatAmount = viewModel?.price {
            addFiatLabelIfNeeded()
            fiatLabel?.text = fiatAmount
        } else {
            removeFiatLabelIfNeeded()
        }

        if let presentationLocale, let presentationTraits {
            configureSendPresentation(locale: presentationLocale, traits: presentationTraits)
        }
        setNeedsLayout()
    }
}
