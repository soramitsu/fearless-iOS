import Foundation
import UIKit

public final class SoramitsuTableViewTitledHeader: NSObject {

	let title: String

	public var insets: SoramitsuInsets

    public var font: FontData = FontType.textL

    public var textColor: SoramitsuColor = .fgPrimary

	public var textAlignment: NSTextAlignment = .left

	public var backgroundColor: SoramitsuColor

	public init(title: String, insets: SoramitsuInsets = .zero, backgroundColor: SoramitsuColor = .bgSurface) {
		self.title = title
		self.insets = insets
		self.backgroundColor = backgroundColor
	}
}

extension SoramitsuTableViewTitledHeader: SoramitsuTableViewItemProtocol {
	public var cellType: AnyClass {
		return SoramitsuTableViewTitledHeaderCell.self
	}
}
