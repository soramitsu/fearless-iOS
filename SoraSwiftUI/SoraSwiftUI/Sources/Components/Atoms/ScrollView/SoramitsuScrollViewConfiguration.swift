import UIKit

public class SoramitsuScrollViewConfiguration<Type: UIScrollView & Element>: SoramitsuViewConfiguration<Type> {

	public var showsVerticalScrollIndicator = false {
		didSet {
			owner?.showsVerticalScrollIndicator = showsVerticalScrollIndicator
		}
	}

	public var showsHorizontalScrollIndicator = false {
		didSet {
			owner?.showsHorizontalScrollIndicator = showsHorizontalScrollIndicator
		}
	}

	public var delaysContentTouches = false {
		didSet {
			owner?.delaysContentTouches = delaysContentTouches
		}
	}

	public var alwaysBounceVertical = false {
		didSet {
			owner?.alwaysBounceVertical = alwaysBounceVertical
		}
	}

	public var keyboardDismissMode: UIScrollView.KeyboardDismissMode = .onDrag {
		didSet {
			owner?.keyboardDismissMode = keyboardDismissMode
		}
	}

	override func configureOwner() {
		super.configureOwner()

		retrigger(self, \.showsVerticalScrollIndicator)
		retrigger(self, \.showsHorizontalScrollIndicator)
		retrigger(self, \.delaysContentTouches)
		retrigger(self, \.alwaysBounceVertical)
		retrigger(self, \.keyboardDismissMode)
	}
}
