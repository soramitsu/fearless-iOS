import UIKit

public protocol SoramitsuLoadingIndicatable: UIView {

	func start()

	func set(progress: CGFloat)

	func stop()
}

public extension SoramitsuLoadingIndicatable {
	func set(progress: CGFloat) {}
}
