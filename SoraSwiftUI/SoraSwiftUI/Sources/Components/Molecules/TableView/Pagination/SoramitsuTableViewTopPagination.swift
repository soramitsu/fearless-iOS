
final class SoramitsuTableViewTopPagination: SoramitsuTableViewBasicPagination {

	private let initialPage = -1

	override init(handler: SoramitsuTableViewPaginationHandlerProtocol) {
		super.init(handler: handler)
		pageNumber = initialPage
		pagePosition  = .top
	}

	override func incrementPage() {
		pageNumber -= 1
	}

	override func isFirstPage() -> Bool {
		return pageNumber == initialPage
	}
}
