import UIKit
import SoraUI

final class WalletScanQRViewLayout: UIView {
    private enum Constants {
        static let titleTopOffset: CGFloat = 64
        static let uploadButtonBottomOffset: CGFloat = 50
        static let uploadButtonWidth: CGFloat = 180
        static let uploadButtonHeight: CGFloat = 40
    }

    let qrFrameView = CameraFrameView()

    let titleLabel: UILabel = {
        let label = UILabel()
        return label
    }()

    let messageLabel: UILabel = {
        let label = UILabel()
        return label
    }()

    let uploadButton: GradientButton = {
        let button = UIFactory.default.createWalletReferralBonusButton()
        button.applyEnabledStyle()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(qrFrameView)
        addSubview(titleLabel)
        addSubview(messageLabel)
        addSubview(uploadButton)

        qrFrameView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(Constants.titleTopOffset)
        }

        uploadButton.snp.makeConstraints { make in
            make.bottom.equalToSuperview().inset(Constants.uploadButtonBottomOffset)
            make.centerX.equalToSuperview()
            make.width.equalTo(Constants.uploadButtonWidth)
            make.height.equalTo(Constants.uploadButtonHeight)
        }

        messageLabel.snp.makeConstraints { make in
            make.bottom.equalTo(uploadButton.snp.top).offset(-UIConstants.bigOffset)
            make.centerX.equalToSuperview()
        }
    }
}
