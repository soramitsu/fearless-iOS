import UIKit
import SoraUI
import SnapKit

public class InfoTitleView: UIView {
    var isHighlighted: Bool = false {
        didSet {
            titleLabel.isHighlighted = isHighlighted
            iconImageView.isHighlighted = isHighlighted
        }
    }

    /// Duration of highlight animation
    var highlightableAnimationDuration: TimeInterval = 0.5

    // Additional options of highligh animation
    var highlightableAnimationOptions = UIView.AnimationOptions.curveEaseOut

    // Starting alha value to animate highlighted cross dissolve
    var highlightedCrossDissolveAlpha: CGFloat = 0.5

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.numberOfLines = 0
        return label
    }()

    let iconImageView: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()

    override public init(frame: CGRect) {
        super.init(frame: frame)

        drawSubviews()
        setupConstraints()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)

        drawSubviews()
        setupConstraints()
    }

    private func drawSubviews() {
        addSubview(titleLabel)
        addSubview(iconImageView)
    }

    private func setupConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(4)
        }

        iconImageView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(8)
            make.trailing.lessThanOrEqualToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(20)
        }
    }
}

extension InfoTitleView: Highlightable {
    public func set(highlighted: Bool, animated: Bool) {
        if animated {
            isHighlighted = !highlighted
            alpha = highlightedCrossDissolveAlpha
            UIView.animate(
                withDuration: highlightableAnimationDuration,
                delay: 0.0,
                options: highlightableAnimationOptions,
                animations: {
                    self.alpha = 1.0
                    self.isHighlighted = highlighted
                },
                completion: { _ in
                    self.alpha = 1.0
                }
            )
        } else {
            isHighlighted = highlighted
        }
    }
}
