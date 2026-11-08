import UIKit

/// The receive QR code: a white field, kept pure white for scanners, set into an inset well (sun-lit redesign).
final class QRView: UIView {
    private enum LayoutConstants {
        static let wellRadius: CGFloat = 30
        static let wellInset: CGFloat = 10
        static let fieldRadius: CGFloat = 20
        static let fieldPadding: CGFloat = 18
        static let imageSize = CGSize(width: 77, height: 34)
    }

    let qrImageView = UIImageView()

    private let well: FWNeuView = {
        let view = FWNeuView()
        view.style = .inset
        view.isUserInteractionEnabled = false
        view.shape = { UIBezierPath(roundedRect: $0, cornerRadius: LayoutConstants.wellRadius) }
        return view
    }()

    private let field: UIView = {
        let view = UIView()
        view.backgroundColor = FWSunlit.Palette.qrField
        view.layer.cornerRadius = LayoutConstants.fieldRadius
        view.layer.cornerCurve = .continuous
        return view
    }()

    private let fearlessIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.qrFearless()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = FWSunlit.Palette.qrField
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
        backgroundColor = .clear
    }

    func setupLayout() {
        addSubview(well)
        well.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(field)
        field.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(LayoutConstants.wellInset)
        }

        field.addSubview(qrImageView)
        qrImageView.snp.makeConstraints { make in
            make.edges.equalTo(field.safeAreaLayoutGuide).inset(LayoutConstants.fieldPadding)
        }

        field.addSubview(fearlessIcon)
        fearlessIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(LayoutConstants.imageSize)
        }
    }
}
