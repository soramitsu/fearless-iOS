import XCTest
@testable import fearless

class PredicateTests: XCTestCase {

    func testDerivationPathPredicate() {
        XCTAssertTrue(NSPredicate.deriviationPath.evaluate(with: "/1//2///3"))
        XCTAssertTrue(NSPredicate.deriviationPath.evaluate(with: "/привет//мир///пароль"))
        XCTAssertTrue(NSPredicate.deriviationPath.evaluate(with: "///пароль"))
        XCTAssertTrue(NSPredicate.deriviationPath.evaluate(with: "//hard"))
        XCTAssertTrue(NSPredicate.deriviationPath.evaluate(with: "/soft"))
        XCTAssertTrue(NSPredicate.deriviationPath.evaluate(with: ""))

        XCTAssertFalse(NSPredicate.deriviationPath.evaluate(with: "soft"))
        XCTAssertFalse(NSPredicate.deriviationPath.evaluate(with: "/soft/"))
        XCTAssertFalse(NSPredicate.deriviationPath.evaluate(with: "/soft//"))
        XCTAssertFalse(NSPredicate.deriviationPath.evaluate(with: "/soft//hard///"))
    }

}
