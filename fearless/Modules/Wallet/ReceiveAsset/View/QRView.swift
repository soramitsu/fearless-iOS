import UIKit

final class QRView: UIView {
    private enum LayoutConstants {
        static let cornerRadius: CGFloat = 24
        static let imageSize = CGSize(width: 77, height: 34)
    }

    let qrImageView = UIImageView()

    private let fearlessIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.qrFearless()
        imageView.backgroundColor = R.color.colorWhite()
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        backgroundColor = R.color.colorWhite()
        layer.cornerRadius = LayoutConstants.cornerRadius
    }

    func setupLayout() {
        addSubview(qrImageView)
        qrImageView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(UIConstants.hugeOffset)
            make.trailing.bottom.equalToSuperview().offset(-UIConstants.hugeOffset)
        }

        addSubview(fearlessIcon)
        fearlessIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(LayoutConstants.imageSize)
        }
    }
}
