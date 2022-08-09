import Foundation
import UIKit

final class CopyableLabelView: UIView {
    private enum Constants {
        static let minIconImageViewSize = CGSize(width: 16, height: 16)
    }

    private let label: UILabel = {
        let label = UILabel()
        label.lineBreakMode = .byTruncatingMiddle
        label.font = UIFont.p2Paragraph
        return label
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconCopy()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        gestureConfigure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = frame.height / 2
    }

    func bind(title: String) {
        label.text = title.uppercased()
    }

    private func gestureConfigure() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
    }

    @objc private func handleTap() {
        UIPasteboard.general.string = label.text
    }

    private func setupLayout() {
        layer.masksToBounds = true
        backgroundColor = R.color.colorWhite8()

        let hStackView = UIFactory.default.createHorizontalStackView(spacing: 6)
        hStackView.distribution = .fillProportionally
        addSubview(hStackView)
        hStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.top.bottom.equalToSuperview().inset(UIConstants.minimalOffset)
        }

        iconImageView.snp.makeConstraints { make in
            make.size.greaterThanOrEqualTo(Constants.minIconImageViewSize)
        }

        hStackView.addArrangedSubview(label)
        hStackView.addArrangedSubview(iconImageView)
    }
}
