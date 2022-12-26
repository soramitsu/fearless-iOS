import UIKit

extension CABasicAnimation {

	convenience init(propertySelector: Selector, duration: CFTimeInterval, toValue: Any? = nil, fromValue: Any? = nil) {
		self.init(keyPath: NSStringFromSelector(propertySelector))
		self.duration = duration
		self.fromValue = fromValue
		self.toValue = toValue
	}
}
