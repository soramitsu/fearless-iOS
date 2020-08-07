import SoraUI

@IBDesignable
final class ExpandableActionControl: BaseActionControl {
    var plusIndicator: PlusIndicatorView! {
        indicator as? PlusIndicatorView
    }

    var titleLabel: UILabel! {
        title as? UILabel
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        configure()
    }

    private func configure() {
        backgroundColor = .clear

        if indicator == nil {
            indicator = PlusIndicatorView()
            indicator?.backgroundColor = .clear
            indicator?.isUserInteractionEnabled = false
        }

        if title == nil {
            title = UILabel()
            title?.backgroundColor = .clear
        }
    }
}
