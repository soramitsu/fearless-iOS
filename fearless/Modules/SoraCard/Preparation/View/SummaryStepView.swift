import UIKit
import SoraSwiftUI

final class SummaryStepView: UIView {
    private let stepView: SoramitsuLabel = {
        let view = SoramitsuLabel()
        view.sora.font = FontType.headline1
        view.sora.textColor = .fgPrimary
        view.sora.alignment = .center
        view.sora.cornerRadius = .extraLarge // .circle
        view.sora.backgroundColor = .bgPage
        return view
    }()

    let titleLable: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline3
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        return label
    }()

    let subtitleLable: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphS
        label.sora.textColor = .fgSecondary
        label.sora.numberOfLines = 0
        return label
    }()

    init(step: String, title: String? = nil, subtitle: String? = nil) {
        super.init(frame: .zero)
        stepView.sora.text = step
        titleLable.sora.text = title
        subtitleLable.sora.text = subtitle
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(step: String, title: String, subtitle: String) {
        stepView.sora.text = step
        titleLable.sora.text = title
        subtitleLable.sora.text = subtitle
    }

    private func setupLayout() {
        addSubview(stepView)
        stepView.snp.makeConstraints {
            $0.leading.top.equalToSuperview()
            $0.size.equalTo(48)
            $0.bottom.lessThanOrEqualToSuperview()
        }

        addSubview(titleLable)
        titleLable.snp.makeConstraints {
            $0.top.trailing.equalToSuperview()
            $0.leading.equalTo(stepView.snp.trailing).offset(16)
        }

        addSubview(subtitleLable)
        subtitleLable.snp.makeConstraints {
            $0.top.equalTo(titleLable.snp.bottom).offset(4)
            $0.leading.equalTo(stepView.snp.trailing).offset(16)
            $0.bottom.trailing.equalToSuperview()
        }
    }
}
