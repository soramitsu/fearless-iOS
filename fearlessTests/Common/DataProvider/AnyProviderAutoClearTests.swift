import XCTest
@testable import fearless
import RobinHood

final class AnyProviderAutoClearTests: XCTestCase {
    func testClear_whenSingleValueProviderExists_thenNilProvider() {
        let cleaner = AnyProviderAutoCleaner()
        let stub = SingleValueProviderStub(item: "value")
        var provider: AnySingleValueProvider<String>? = AnySingleValueProvider(stub)

        cleaner.clear(singleValueProvider: &provider)

        XCTAssertNil(provider)
    }

    func testClear_whenDataProviderExists_thenNilProvider() {
        let cleaner = AnyProviderAutoCleaner()
        let stub = DataProviderStub(models: [AnyProviderAutoClearTestModel(identifier: "model-id")])
        var provider: AnyDataProvider<AnyProviderAutoClearTestModel>? = AnyDataProvider(stub)

        cleaner.clear(dataProvider: &provider)

        XCTAssertNil(provider)
    }

    func testDataProviderChangeItem_whenChangeCarriesValue_thenReturnsInsertedOrUpdatedItem() {
        let inserted = AnyProviderAutoClearTestModel(identifier: "inserted")
        let updated = AnyProviderAutoClearTestModel(identifier: "updated")

        XCTAssertEqual(DataProviderChange.insert(newItem: inserted).item, inserted)
        XCTAssertEqual(DataProviderChange.update(newItem: updated).item, updated)
        XCTAssertNil(DataProviderChange<AnyProviderAutoClearTestModel>.delete(deletedIdentifier: "deleted").item)
    }

    func testDataProviderChange_whenValuesTransition_thenReturnsExpectedChange() {
        typealias TestChange = DataProviderChange<AnyProviderAutoClearTestModel>

        let current = AnyProviderAutoClearTestModel(identifier: "model-id", value: 1)
        let same = AnyProviderAutoClearTestModel(identifier: "model-id", value: 1)
        let changed = AnyProviderAutoClearTestModel(identifier: "model-id", value: 2)
        let inserted = AnyProviderAutoClearTestModel(identifier: "inserted-id", value: 3)
        let missing: AnyProviderAutoClearTestModel? = nil

        XCTAssertNil(TestChange.change(value1: missing, value2: missing))
        XCTAssertNil(TestChange.change(value1: current, value2: same))

        guard case let .insert(newItem)? = TestChange.change(value1: missing, value2: inserted) else {
            return XCTFail("Insert change expected")
        }

        XCTAssertEqual(newItem, inserted)

        guard case let .delete(deletedIdentifier)? = TestChange.change(value1: current, value2: missing) else {
            return XCTFail("Delete change expected")
        }

        XCTAssertEqual(deletedIdentifier, current.identifier)

        guard case let .update(newItem)? = TestChange.change(value1: current, value2: changed) else {
            return XCTFail("Update change expected")
        }

        XCTAssertEqual(newItem, changed)
    }
}

private struct AnyProviderAutoClearTestModel: Identifiable, Equatable {
    let identifier: String
    var value = 0
}
