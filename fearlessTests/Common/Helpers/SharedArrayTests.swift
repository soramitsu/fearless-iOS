import XCTest
@testable import fearless

class SharedArrayTests: XCTestCase {

    func testQueryFunctions() {
        let items = [1, 2, 3]
        let sharedList = SharedList(items: items)

        XCTAssertEqual(items, sharedList.items)
        XCTAssertEqual(items.count, sharedList.count)
        XCTAssertEqual(items.contains(3), sharedList.contains(3))
        XCTAssertEqual(items.contains(4), sharedList.contains(4))
        XCTAssertEqual(items.firstIndex(of: 3), sharedList.firstIndex(of: 3))
        XCTAssertEqual(items.firstIndex(of: 4), sharedList.firstIndex(of: 4))
    }

    func testAppend() {
        let items = [1, 2, 3]
        let sharedList = SharedList(items: items)

        sharedList.append(4)

        XCTAssertEqual(items + [4], sharedList.items)
    }

    func testAppendSequence() {
        let items = [1, 2, 3]
        let sharedList = SharedList(items: items)

        sharedList.append(contentsOf: [4, 5])

        XCTAssertEqual(items + [4, 5], sharedList.items)
    }

    func testRemoveExistingItem() {
        let items = [1, 2, 3]
        let sharedList = SharedList(items: items)

        sharedList.remove(2)

        XCTAssertEqual([1, 3], sharedList.items)
    }

    func testRemoveNonExistingItem() {
        let items = [1, 2, 3]
        let sharedList = SharedList(items: items)

        sharedList.remove(4)

        XCTAssertEqual([1, 2, 3], sharedList.items)
    }

    func testRemoveAtIndex() {
        let items = [1, 2, 3]
        let sharedList = SharedList(items: items)

        sharedList.remove(at: 0)

        XCTAssertEqual([2, 3], sharedList.items)
    }
}
