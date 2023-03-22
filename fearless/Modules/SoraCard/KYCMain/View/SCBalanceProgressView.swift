import UIKit
import SnapKit
import SoraSwiftUI

final class SCBalanceProgressView: UIView {
    private let progressBGView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.backgroundColor = .bgSurfaceVariant
        view.sora.cornerRadius = .custom(2)
        return view
    }()

    private let progressView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.backgroundColor = .accentPrimary
        view.sora.cornerRadius = .custom(2)
        return view
    }()

    private let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldS
        label.sora.textColor = .accentPrimary
        label.sora.numberOfLines = 0
        label.sora.alignment = .right
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupInitialLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(progressPercentage: Float, title: String) {
        UIView.animate(withDuration: 0.3) {
            self.progressView.snp.remakeConstraints {
                $0.leading.top.bottom.equalToSuperview()
                $0.width.greaterThanOrEqualTo(4)
                $0.width.equalToSuperview().multipliedBy(progressPercentage)
            }
            self.layoutIfNeeded()
        }

        titleLabel.sora.text = title
    }

    private func setupInitialLayout() {
        addSubview(progressBGView) {
            $0.top.equalToSuperview().inset(8)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(4)
        }

        progressBGView.addSubview(progressView) {
            $0.leading.top.bottom.equalToSuperview()
            $0.width.greaterThanOrEqualTo(4)
            $0.width.equalToSuperview().multipliedBy(0.01)
        }

        addSubview(titleLabel) {
            $0.top.equalTo(progressBGView.snp.bottom).offset(4)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }
}
