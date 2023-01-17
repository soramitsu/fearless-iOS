import Foundation
import UIKit

final class MarketButton: UIControl {
    private enum Constants {
        static let imageViewSize = CGSize(width: 32, height: 32)
    }

    private let titleLabel = UILabel()
    private let settingView = RoundedSettingIcon()

    var locale: Locale = .current

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        rounded()
        settingView.rounded()
    }

    func setTitle(_ title: String) {
        var marketString = R.string.localizable
            .polkaswapMarketStub(preferredLanguages: locale.rLanguages)
        marketString += ":"
        let joinedTitle = [marketString, title.uppercased()].joined(separator: " ")
        let attributedTitle = NSMutableAttributedString(string: joinedTitle)

        attributedTitle.addAttribute(
            NSAttributedString.Key.foregroundColor,
            value: R.color.colorStrokeGray()!,
            range: (joinedTitle as NSString).range(of: marketString)
        )
        attributedTitle.addAttribute(
            NSAttributedString.Key.foregroundColor,
            value: R.color.colorWhite()!,
            range: (joinedTitle as NSString).range(of: title)
        )

        attributedTitle.addAttribute(
            NSAttributedString.Key.font,
            value: UIFont.p1Paragraph,
            range: (joinedTitle as NSString).range(of: marketString)
        )
        attributedTitle.addAttribute(
            NSAttributedString.Key.font,
            value: UIFont.h3Title,
            range: (joinedTitle as NSString).range(of: title)
        )

        titleLabel.attributedText = attributedTitle
    }

    private func setup() {
        backgroundColor = R.color.colorSemiBlack()
    }

    private func setupLayout() {
        addSubview(titleLabel)
        addSubview(settingView)

        titleLabel.snp.makeConstraints { make in
            make.top.leading.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.centerY.equalToSuperview()
        }

        settingView.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.leading.equalTo(titleLabel.snp.trailing).offset(UIConstants.defaultOffset)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.imageViewSize)
        }
    }
}

private final class RoundedSettingIcon: UIView {
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconSettingMarket()
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        backgroundColor = R.color.colorWhite8()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIConstants.defaultOffset)
        }
    }
}
