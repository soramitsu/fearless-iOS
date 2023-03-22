import UIKit

public class SoramitsuTableViewCellConfiguration<Type: SoramitsuTableViewCell>: SoramitsuViewConfiguration<Type> {

	public override var backgroundColor: SoramitsuColor {
		didSet {
			owner?.backgroundColor = palette.color(backgroundColor)
			owner?.contentView.backgroundColor = palette.color(backgroundColor)
		}
	}

	public var selectionColor: SoramitsuColor? = nil {
		didSet {
			if let color = selectionColor {
                backgroundColor = .custom(uiColor: .clear)
				let view = SoramitsuView(style: style)
				view.sora.useAutoresizingMask = true
				view.sora.backgroundColor = color
				selectionStyle = .default
				owner?.selectedBackgroundView = view
			} else {
				owner?.selectedBackgroundView = nil
				selectionStyle = .none
			}
		}
	}

	public var selectionStyle: UITableViewCell.SelectionStyle = .none {
		didSet {
			owner?.selectionStyle = selectionStyle
		}
	}

	override init(style: SoramitsuStyle) {
		super.init(style: style)
		useAutoresizingMask = true
	}

	public override func styleDidChange(options: UpdateOptions) {
		super.styleDidChange(options: options)
		if options.contains(.palette) {
			retrigger(self, \.selectionColor)
		}
	}

	override func configureOwner() {
		super.configureOwner()
		retrigger(self, \.selectionColor)
	}
}
