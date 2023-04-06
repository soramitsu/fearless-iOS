import UIKit

public class SoramitsuViewControllerConfiguration<Type: Organism & UIViewController>: SoramitsuConfiguration<Type>, SoramitsuStatusBarManaging {

	public var statusBarStyle: StatusBarStyle = .default {
		didSet {
			owner?.setNeedsStatusBarAppearanceUpdate()
		}
	}

	public var statusBarHidden = false {
		didSet {
			owner?.setNeedsStatusBarAppearanceUpdate()
		}
	}

	public var statusBarUpdateAnimation: UIStatusBarAnimation = .fade {
		didSet {
			owner?.setNeedsStatusBarAppearanceUpdate()
		}
	}

	public var hidesTabBar: Bool = false {
		didSet {
			owner?.hidesBottomBarWhenPushed = hidesTabBar
		}
	}

	public override func styleDidChange(options: UpdateOptions) {
		super.styleDidChange(options: options)
		if options.contains(.statusBar) {
			retrigger(self, \.statusBarStyle)
		}
	}

	override func configureOwner() {
		super.configureOwner()

		retrigger(self, \.statusBarStyle)
		retrigger(self, \.statusBarHidden)
	}
}
