extension Array {

	mutating func append(_ newElement: Element, if conditionClosure: @autoclosure () -> Bool) {
		if conditionClosure() {
			append(newElement)
		}
	}

	mutating func insert(_ newElement: Element, at index: Int, if conditionClosure: @autoclosure () -> Bool) {
		if conditionClosure() {
			insert(newElement, at: index)
		}
	}

	subscript(index: Int, element: Element?) -> Element? {
		let arr = self
		guard index >= 0, index < arr.count else { return element }
		return arr[index]
	}

	subscript(safe index: Int) -> Element? {
		let arr = self
		guard index >= 0, index < arr.count else { return nil }
		return arr[index]
	}
}

public extension Array where Element: Hashable {

	struct DiffableResult<Element> {
		struct DiffableItem<Element> {
			let element: Element
			let offset: Int
		}

		let inserted: [DiffableItem<Element>]
		let removed: [DiffableItem<Element>]
	}

	func getDifference(form other: [Element]) -> DiffableResult<Element> {
		let thisSet = Set(self)
		let otherSet = Set(other)

		let insertedElements = Array(otherSet.subtracting(thisSet))
		let removedElements = Array(thisSet.subtracting(otherSet))

		let inserted = insertedElements.compactMap { element -> DiffableResult<Element>.DiffableItem<Element>? in
			guard let index = other.firstIndex(of: element) else { return nil }
			return DiffableResult.DiffableItem(element: element, offset: index)
		}

		let removed = removedElements.compactMap { element -> DiffableResult<Element>.DiffableItem<Element>? in
			guard let index = self.firstIndex(of: element) else { return nil }
			return DiffableResult.DiffableItem(element: element, offset: index)
		}

		return DiffableResult(inserted: inserted, removed: removed)
	}
}
