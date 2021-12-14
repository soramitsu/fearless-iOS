import UIKit
import SoraUI

final class ReceiveAssetViewLayout: UIView {
    enum Constants {
        static let horizontalOffset = 16
        static let navigationVerticalOffset = 8
        static let accountToQrLabelSpacing = 41
        static let qrLabelToImageSpacing = 24
        static let imageSize = 280
    }

    let navigationLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = R.color.colorWhite()
        label.textAlignment = .center
        return label
    }()

    let shareButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconShare()?.withRenderingMode(.alwaysTemplate), for: .normal)
        return button
    }()

    let accountView: DetailsTriangularedView = {
        let detailsView = UIFactory().createAccountView()
        return detailsView
    }()

    let qrLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    let imageView = UIImageView()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    lazy var navigationBar: BaseNavigationBar = {
        let navBar = BaseNavigationBar()
        navBar.set(.present)
        return navBar
    }()

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
        addSubview(navigationBar)
        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        navigationBar.setCenterViews([navigationLabel])
        navigationBar.setRightViews([shareButton])

        addSubview(accountView)
        accountView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().offset(Constants.horizontalOffset)
            make.top.equalTo(navigationBar).offset(Constants.navigationVerticalOffset)
        }

        addSubview(qrLabel)
        qrLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().offset(Constants.horizontalOffset)
            make.top.equalTo(accountView).offset(Constants.accountToQrLabelSpacing)
        }

        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.size.equalTo(280 * designScaleRatio.width)
            make.top.equalTo(qrLabel.snp.bottom).offset(Constants.qrLabelToImageSpacing)
            make.centerX.equalToSuperview()
        }
    }

    func applyLocalization() {
        qrLabel.text = R.string.localizable.walletReceiveQrDescription(preferredLanguages: locale.rLanguages)
    }
}

extension ReceiveAssetViewLayout: AdaptiveDesignable {}
