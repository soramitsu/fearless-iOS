import UIKit

public class SoramitsuStackViewConfiguration<Type: SoramitsuStackView>: SoramitsuViewConfiguration<Type> {

	public var axis: NSLayoutConstraint.Axis = .horizontal {
		didSet {
			owner?.axis = axis
		}
	}

	public var distribution: UIStackView.Distribution = .fill {
		didSet {
			owner?.distribution = distribution
		}
	}

	public var alignment: UIStackView.Alignment = .fill {
		didSet {
			owner?.alignment = alignment
		}
	}

	override func configureOwner() {
		super.configureOwner()

		retrigger(self, \.axis)
		retrigger(self, \.distribution)
		retrigger(self, \.alignment)
	}
}
