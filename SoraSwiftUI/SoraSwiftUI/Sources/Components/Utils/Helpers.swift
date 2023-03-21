import UIKit

public extension UIView {
	func addSubviews(_ views: UIView...) {
		addSubviews(views)
	}

	func addSubviews(_ views: [UIView]) {
		for view in views {
			addSubview(view)
		}
	}

	func rebuildLayout(animated: Bool = false,
					   duration: Double = 0.2,
					   options: UIView.AnimationOptions = [],
					   completion: ((Bool) -> Void)? = nil) {
		if animated {
			UIView.animate(withDuration: duration,
						   delay: 0,
						   options: options,
						   animations: {
							self.setNeedsLayout()
							self.layoutIfNeeded()
			}, completion: completion)
		} else {
			setNeedsLayout()
			layoutIfNeeded()
			completion?(true)
		}
	}
}

public extension UIStackView {

	func addArrangedSubviews(_ views: UIView...) {
		addArrangedSubviews(views)
	}

	func addArrangedSubviews(_ views: [UIView]) {
		views.forEach { addArrangedSubview($0) }
	}

	func removeArrangedSubviews() {
		for subview in self.arrangedSubviews {
			subview.removeFromSuperview()
		}
	}
}

public func setAutoresizingMask(enabled: Bool, _ views: UIView...) {
	setAutoresizingMask(enabled: enabled, views)
}

public func setAutoresizingMask(enabled: Bool, _ views: [UIView]) {
	for view in views {
		view.translatesAutoresizingMaskIntoConstraints = enabled
	}
}

public extension UIView {
	func pinToSuperView(inset: CGFloat = 0.0, respectingSafeArea: Bool = true) {
		pinToSuperView(insets: SoramitsuInsets(top: inset,
									   left: inset,
									   bottom: inset,
									   right: inset),
					   respectingSafeArea: respectingSafeArea)
	}

	func pinToSuperView(insets: SoramitsuInsets, respectingSafeArea: Bool = true) {

		guard let superview = superview else { return }

		let top = respectingSafeArea ? superview.gSafeTopAnchor : superview.topAnchor
		let leading = respectingSafeArea ? superview.gSafeLeadingAnchor : superview.leadingAnchor
		let trailing = respectingSafeArea ? superview.gSafeTrailingAnchor : superview.trailingAnchor
		let bottom = respectingSafeArea ? superview.gSafeBottomAnchor : superview.bottomAnchor

		translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			topAnchor.constraint(equalTo: top, constant: insets.top),
			leadingAnchor.constraint(equalTo: leading, constant: insets.left),
			trailingAnchor.constraint(equalTo: trailing, constant: -insets.right),
			bottomAnchor.constraint(equalTo: bottom, constant: -insets.bottom)
		])
	}

	func pin(to view: UIView, insets: SoramitsuInsets = .zero) {
		translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			topAnchor.constraint(equalTo: view.topAnchor, constant: insets.top),
			leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: insets.left),
			trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -insets.right),
			bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -insets.bottom)
		])
	}

	func removeAllConstraints() {
		let superviewConstraints = superview?.constraints.filter {
			$0.firstItem as? UIView == self || $0.secondItem as? UIView == self
		} ?? []
		superview?.removeConstraints(superviewConstraints)
		removeConstraints(constraints)
	}
}

public extension UIView {

	var universalSafeAreaInsets: UIEdgeInsets {
		return safeAreaInsets
	}

	var gSafeTopAnchor: NSLayoutYAxisAnchor {
		return safeAreaLayoutGuide.topAnchor
	}

	var gSafeBottomAnchor: NSLayoutYAxisAnchor {
		return safeAreaLayoutGuide.bottomAnchor
	}

	var gSafeLeadingAnchor: NSLayoutXAxisAnchor {
		return safeAreaLayoutGuide.leadingAnchor
	}

	var gSafeTrailingAnchor: NSLayoutXAxisAnchor {
		return safeAreaLayoutGuide.trailingAnchor
	}
}

public extension UIView {
	func makeSquare(side: CGFloat? = nil) {
		heightAnchor.constraint(equalTo: widthAnchor).isActive = true
		if let side = side {
			heightAnchor.constraint(equalToConstant: side).isActive = true
		}
	}
}

public extension CGRect {

	var center: CGPoint {
		return CGPoint(x: midX, y: midY)
	}
}

public extension UIScrollView {
	var isScrolling: Bool {
		return isDragging && !isDecelerating || isTracking
	}
}

public extension UITextField {
	func moveCursorToEnd() {
		selectedTextRange = textRange(from: endOfDocument, to: endOfDocument)
	}
}

public extension CGPoint {
	static func / (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
		return CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
	}

	static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
		return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
	}

	static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
		return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
	}
}

public extension CATransaction {

	static func performWithoutAnimations(_ actions: () -> Void) {
		begin()
		setDisableActions(true)
		actions()
		commit()
	}
}

extension CGFloat {
	var toDouble: Double {
		Double(self)
	}
}

extension Double {
	var toCGFloat: CGFloat {
		CGFloat(self)
	}
}
extension Int {
	var toCGFloat: CGFloat {
		CGFloat(self)
	}

	var toUInt: UInt? {
		UInt(exactly: self)
	}
}

extension UInt64 {
	var toCGFloat: CGFloat {
		CGFloat(self)
	}
}

extension CGSize {

	var ratio: CGFloat {
		height / width
	}

	static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
		return CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
	}

	static func - (lhs: CGSize, rhs: CGSize) -> CGSize {
		return CGSize(width: lhs.width - rhs.width, height: lhs.height - rhs.height)
	}

	static func += (lhs: inout CGSize, rhs: CGSize) {
		lhs = lhs + rhs
	}

	static func -= (lhs: inout CGSize, rhs: CGSize) {
		lhs = lhs - rhs
	}
}
