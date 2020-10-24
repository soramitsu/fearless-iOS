import UIKit
import SoraUI

protocol DetailsTriangularedViewDelegate: class {
    func detailsViewDidSelectAction(_ details: DetailsTriangularedView)
}

class DetailsTriangularedView: UIView {
    enum Layout {
        case singleTitle
        case largeIconTitleSubtitle
        case smallIconTitleSubtitle
    }

    private(set) var backgroundView: TriangularedView!
    private(set) var iconView: UIImageView!
    private(set) var titleLabel: UILabel!
    private(set) var subtitleLabel: UILabel?
    private(set) var actionButton: RoundedButton!

    weak var delegate: DetailsTriangularedViewDelegate?

    var horizontalSpacing: CGFloat = 8.0 {
        didSet {
            setNeedsLayout()
        }
    }

    var iconRadius: CGFloat = 16.0 {
        didSet {
            setNeedsLayout()
        }
    }

    var contentInsets = UIEdgeInsets(top: 12.0, left: 12.0, bottom: 12.0, right: 16.0) {
        didSet {
            setNeedsLayout()
        }
    }

    var layout: Layout = .largeIconTitleSubtitle {
        didSet {
            switch layout {
            case .largeIconTitleSubtitle, .smallIconTitleSubtitle:
                if subtitleLabel == nil {
                    let label = UILabel()
                    subtitleLabel = label
                    addSubview(label)
                }
            case .singleTitle:
                if subtitleLabel != nil {
                    subtitleLabel?.removeFromSuperview()
                    subtitleLabel = nil
                }
            }

            setNeedsLayout()
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        configure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        backgroundView.frame = bounds

        actionButton.frame = CGRect(x: bounds.maxX - bounds.height,
                                    y: bounds.minY,
                                    width: bounds.height,
                                    height: bounds.height)

        switch layout {
        case .largeIconTitleSubtitle:
            layoutLargeIconTitleSubtitle()
        case .smallIconTitleSubtitle:
            layoutSmallIconTitleSubtitle()
        case .singleTitle:
            layoutSingleTitle()
        }
    }

    private func layoutLargeIconTitleSubtitle() {
        let titleHeight = titleLabel.intrinsicContentSize.height
        let labelX = bounds.minX + contentInsets.left + 2.0 * iconRadius + horizontalSpacing
        titleLabel.frame = CGRect(x: labelX,
                                  y: bounds.minY + contentInsets.top,
                                  width: actionButton.frame.minX - labelX,
                                  height: titleHeight)

        let subtitleHeight = subtitleLabel?.intrinsicContentSize.height ?? 0.0
        subtitleLabel?.frame = CGRect(x: labelX,
                                     y: bounds.maxY - contentInsets.bottom - subtitleHeight,
                                     width: actionButton.frame.minX - labelX,
                                     height: subtitleHeight)

        iconView.frame = CGRect(x: bounds.minX + contentInsets.left,
                                y: bounds.midY - iconRadius,
                                width: 2.0 * iconRadius,
                                height: 2.0 * iconRadius)
    }

    private func layoutSmallIconTitleSubtitle() {
        let titleHeight = titleLabel.intrinsicContentSize.height
        let titleX = bounds.minX + contentInsets.left
        titleLabel.frame = CGRect(x: titleX,
                                  y: bounds.minY + contentInsets.top,
                                  width: actionButton.frame.minX - titleX,
                                  height: titleHeight)

        let subtitleHeight = subtitleLabel?.intrinsicContentSize.height ?? 0.0
        let subtitleX = titleX + 2.0 * iconRadius + horizontalSpacing
        subtitleLabel?.frame = CGRect(x: subtitleX,
                                      y: bounds.maxY - contentInsets.bottom - subtitleHeight,
                                      width: actionButton.frame.minX - subtitleX,
                                      height: subtitleHeight)

        let subtitleCenter = subtitleLabel?.frame.midY ?? bounds.midY
        iconView.frame = CGRect(x: titleX,
                                y: subtitleCenter - iconRadius,
                                width: 2.0 * iconRadius,
                                height: 2.0 * iconRadius)
    }

    private func layoutSingleTitle() {
        let titleHeight = titleLabel.intrinsicContentSize.height
        let labelX = bounds.minX + contentInsets.left + 2.0 * iconRadius + horizontalSpacing
        titleLabel.frame = CGRect(x: labelX,
                                  y: bounds.midY - titleHeight / 2.0,
                                  width: actionButton.frame.minX - labelX,
                                  height: titleHeight)

        iconView.frame = CGRect(x: bounds.minX + contentInsets.left,
                                y: bounds.midY - iconRadius,
                                width: 2.0 * iconRadius,
                                height: 2.0 * iconRadius)
    }

    private func configure() {
        self.backgroundColor = UIColor.clear

        configureBackgroundViewIfNeeded()
        configureActionButtonIfNeeded()
        configureContentViewIfNeeded()
    }

    private func configureBackgroundViewIfNeeded() {
        if backgroundView == nil {
            backgroundView = TriangularedView()
            backgroundView.shadowOpacity = 0.0
            addSubview(backgroundView)
        }
    }

    private func configureActionButtonIfNeeded() {
        if actionButton == nil {
            actionButton = RoundedButton()
            actionButton.contentInsets = .zero
            actionButton.roundedBackgroundView?.fillColor = .clear
            actionButton.roundedBackgroundView?.highlightedFillColor = .clear
            actionButton.roundedBackgroundView?.shadowOpacity = 0.0
            actionButton.changesContentOpacityWhenHighlighted = true
            addSubview(actionButton)

            actionButton.addTarget(self,
                                   action: #selector(didSelectAction),
                                   for: .touchUpInside)
        }
    }

    private func configureContentViewIfNeeded() {
        if iconView == nil {
            iconView = UIImageView()
            addSubview(iconView)
        }

        if titleLabel == nil {
            titleLabel = UILabel()
            addSubview(titleLabel)
        }

        if subtitleLabel == nil, layout != .singleTitle {
            let label = UILabel()
            addSubview(label)
            subtitleLabel = label
        }
    }

    @objc private func didSelectAction() {
        delegate?.detailsViewDidSelectAction(self)
    }
}
