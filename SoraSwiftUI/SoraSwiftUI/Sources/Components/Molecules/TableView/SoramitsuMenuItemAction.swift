import Foundation
import UIKit

public final class SoramitsuMenuItemAction {

	let selector: Selector

	let title: String

	public init(selector: Selector, title: String) {
		self.selector = selector
		self.title = title
	}

	func makeMenuItem() -> UIMenuItem {
		return UIMenuItem(title: title, action: selector)
	}
}
