import CoreGraphics
import UIKit

public final class SoramitsuLoadingTableViewItem: NSObject {

	let placeholderType: SoramitsuLoadingPlaceholderType

	let insets: SoramitsuInsets

	let cornerRadius: Radius

	private let height: CGFloat?
	private let privateCellType: AnyClass

	convenience public init(height: CGFloat,
							type: SoramitsuLoadingPlaceholderType = .shimmer,
							insets: SoramitsuInsets = SoramitsuInsets(horizontal: Padding.Horizontal.molecule.value,
                                                                      vertical: Padding.Vertical.molecule.value),
							cornerRadius: Radius = .medium) {
		self.init(insets: insets,
				  cornerRadius: cornerRadius,
				  cellType: SoramitsuLoadingTableViewCell.self,
				  type: type,
				  height: height)
	}

	convenience public init(cellType: AnyClass, height: CGFloat? = nil) {
		self.init(insets: .zero, cornerRadius: .zero, cellType: cellType, type: .none, height: height)
	}

	private init(insets: SoramitsuInsets,
				 cornerRadius: Radius,
				 cellType: AnyClass,
				 type: SoramitsuLoadingPlaceholderType,
				 height: CGFloat?) {
		self.insets = insets
		self.cornerRadius = cornerRadius
		self.privateCellType = cellType
		self.height = height
		self.placeholderType = type

		super.init()
	}
}

extension SoramitsuLoadingTableViewItem: SoramitsuTableViewItemProtocol {
	public var cellType: AnyClass {
		privateCellType
	}

	public func itemHeight(forWidth width: CGFloat, context: SoramitsuTableViewContext?) -> CGFloat {
		if let height = height {
			return height + insets.vertical
		}

		return UITableView.automaticDimension
	}
}
