import SoraSwiftUI

final class TermsConditionsButton: UIControl {
    private enum LayoutConstants {
        static let imageSize: CGFloat = 32
    }

    let titleLable: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textM
        label.sora.textColor = .fgPrimary
        return label
    }()

    private let iconImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.sora.picture = .icon(image: R.image.iconSmallArrow()!, color: .fgSecondary)
        return view
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
        snp.makeConstraints { make in
            make.height.equalTo(64)
        }

        addSubview(titleLable)
        titleLable.snp.makeConstraints {
            $0.top.bottom.leading.equalToSuperview()
        }

        addSubview(iconImageView)
        iconImageView.snp.makeConstraints {
            $0.leading.equalTo(titleLable.snp.trailing).offset(UIConstants.defaultOffset)
            $0.size.equalTo(LayoutConstants.imageSize)
            $0.trailing.equalToSuperview()
            $0.centerY.equalToSuperview()
        }
    }
}
