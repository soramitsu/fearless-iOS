import UIKit

public class SoramitsuImageViewConfiguration<Type: UIImageView & Atom>: SoramitsuViewConfiguration<Type> {

	public var picture: Picture? {
		didSet {
			if let picture = picture {
				switch picture {
				case .logo: break
				case .icon(_, let color):
					tintColor = color
				}
			}
			owner?.image = picture?.image
		}
	}

	public var contentMode: UIView.ContentMode = .scaleAspectFit {
		didSet {
			owner?.contentMode = contentMode
		}
	}

	override func configureOwner() {
		super.configureOwner()
		owner?.accessibilityTraits = .image
		retrigger(self, \.contentMode)
	}
}
