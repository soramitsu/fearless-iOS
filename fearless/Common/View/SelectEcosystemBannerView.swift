import Foundation
import UIKit

final class SelectEcosystemBannerView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h3Title
        label.numberOfLines = 0
        return label
    }()

    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()

    let actionButton: TriangularedButton = {
        let button = UIFactory.default.createMainActionButton()
        button.triangularedView?.shadowOpacity = 0
        button.triangularedView?.fillColor = .clear
        button.triangularedView?.highlightedFillColor = .clear
        button.triangularedView?.strokeColor = R.color.colorWhite8()!
        button.triangularedView?.highlightedStrokeColor = R.color.colorWhite8()!
        button.triangularedView?.strokeWidth = 1

        button.imageWithTitleView?.titleColor = R.color.colorWhite()
        button.imageWithTitleView?.titleFont = .h6Title
        return button
    }()
    
    private let ecosystem: AccountCreateEcosystem
    
    init(ecosystem: AccountCreateEcosystem) {
        self.ecosystem = ecosystem
        super.init(frame: .zero)
        backgroundColor = R.color.colorWhite8()
        layer.cornerRadius = 15
        clipsToBounds = true
        switch ecosystem {
        case .regular:
            imageView.image = R.image.regularBanner()
        case .ton:
            imageView.image = R.image.tonBanner()
        }
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.height.equalTo(139)
            make.edges.equalToSuperview()
        }

        addSubview(titleLabel)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().inset(24)
        }

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(titleLabel.snp.bottom).offset(UIConstants.defaultOffset)
            make.leading.equalToSuperview().offset(24)
            make.bottom.equalToSuperview().inset(24)
            make.height.equalTo(32)
            make.width.greaterThanOrEqualTo(62)
        }
    }
}
