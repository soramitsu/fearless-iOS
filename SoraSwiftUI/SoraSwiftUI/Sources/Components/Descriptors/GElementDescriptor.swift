import UIKit

public protocol SoramitsuElementDescriptor {

	associatedtype SoramitsuViewType

	func configure(_ element: SoramitsuViewType)
}

public class AnyElementDescriptor<SoramitsuElement>: SoramitsuElementDescriptor {

	private let configure: (SoramitsuElement) -> Void

	public init<Descriptor: SoramitsuElementDescriptor>(descriptor: Descriptor) where
		Descriptor.SoramitsuViewType == SoramitsuElement, Descriptor.SoramitsuViewType: UIView & Element {
		configure = descriptor.configure
	}

	public func configure(_ element: SoramitsuElement) {
		configure(element)
	}
}
