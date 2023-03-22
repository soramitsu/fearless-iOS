import UIKit

open class SoramitsuViewController: SoramitsuBaseViewController, Organism {

	public let sora: SoramitsuViewControllerConfiguration<SoramitsuViewController>

	public override var prefersStatusBarHidden: Bool {
		return sora.statusBarHidden
	}
	public override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
		return sora.statusBarUpdateAnimation
	}
	public override var preferredStatusBarStyle: UIStatusBarStyle {
		return sora.style.statusBar.value(for: sora.statusBarStyle)
	}

	public init() {
		let style = SoramitsuUI.shared.style
		sora = SoramitsuViewControllerConfiguration(style: style)
		super.init(style: style)
		sora.owner = self
	}

	override init(style: SoramitsuStyle) {
		sora = SoramitsuViewControllerConfiguration(style: style)
		super.init(style: style)
		sora.owner = self
	}
}
