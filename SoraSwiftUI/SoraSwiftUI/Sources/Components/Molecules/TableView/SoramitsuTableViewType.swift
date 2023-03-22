import UIKit

public enum SoramitsuTableViewType {

	case grouped

	case plain

	func makeDescriptor() -> AnyElementDescriptor<SoramitsuTableView> {
		switch self {
		case .grouped:
			return AnyElementDescriptor(descriptor: SoramitsuGroupedTableViewDescriptor())
		case .plain:
			return AnyElementDescriptor(descriptor: SoramitsuPlainTableViewDescriptor())
		}
	}

	func uiType() -> UITableView.Style {
		switch self {
		case .plain:
			return .plain
		case .grouped:
			return .grouped
		}
	}
}
