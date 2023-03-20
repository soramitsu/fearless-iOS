import UIKit
import SoraSwiftUI

final class SCFeeLabelView: UIView {
    let iconView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        return view
    }()

    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.displayM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        setupInitialLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupInitialLayout() {
        addSubview(iconView)
        addSubview(titleLabel)

        iconView.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.centerY.equalToSuperview()
            $0.size.equalTo(24)
        }

        titleLabel.snp.makeConstraints {
            $0.leading.equalTo(iconView.snp.trailing).offset(10)
            $0.top.bottom.trailing.equalToSuperview()
        }
    }
}
