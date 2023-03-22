import Foundation

public enum NextPageLoadResult {
	case loadingSuccessWithItems([SoramitsuTableViewItemProtocol], hasNextPage: Bool)
	case loadingSuccessWithSections([SoramitsuTableViewSectionProtocol], hasNextPage: Bool)
	case loadingSuccessWith(items: [SoramitsuTableViewItemProtocol], sections: [SoramitsuTableViewSectionProtocol], hasNextPage: Bool)
	case loadingFailure
}

public enum PaginationType {
	case both, bottom
}

public protocol SoramitsuTableViewPaginationHandlerProtocol: AnyObject {

	var paginationType: PaginationType { get }

	func didRequestNewPage(with pageNumber: UInt, completion: @escaping(NextPageLoadResult) -> Void)

	func didRequestNewPage(with pageNumber: Int, completion: @escaping(NextPageLoadResult) -> Void)

	func possibleToMakePullToRefresh() -> Bool
}

public extension SoramitsuTableViewPaginationHandlerProtocol {

	func didRequestNewPage(with pageNumber: Int, completion: @escaping(NextPageLoadResult) -> Void) {
		if let unsigned = pageNumber.toUInt {
			didRequestNewPage(with: unsigned, completion: completion)
		}
	}

	func didRequestNewPage(with pageNumber: UInt, completion: @escaping(NextPageLoadResult) -> Void) {}

	var paginationType: PaginationType {
		return .bottom
	}

	func possibleToMakePullToRefresh() -> Bool {
		return false
	}
}
