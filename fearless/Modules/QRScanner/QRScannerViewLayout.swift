import UIKit
import SoraUI

final class QRScannerViewLayout: UIView {
    let qrFrameView: CameraFrameView = {
        let view = CameraFrameView()
        view.cornerRadius = 10.0
        view.windowSize = CGSize(width: 225.0, height: 225.0)
        view.windowPosition = CGPoint(x: 0.5, y: 0.47)
        view.fillColor = R.color.colorQrOverlay()!
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 2
        label.textAlignment = .center
        return label
    }()

    let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .p0Paragraph
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(qrFrameView)

        qrFrameView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
        }

        addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(safeAreaLayoutGuide.snp.top).inset(58.0)
        }

        addSubview(messageLabel)
        messageLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).inset(40.0)
        }
    }
}
