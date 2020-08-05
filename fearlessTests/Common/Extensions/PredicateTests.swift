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
        XCTAssertFalse(NSPredicate.deriviationPath.evaluate(with: "////hard"))
        XCTAssertFalse(NSPredicate.deriviationPath.evaluate(with: "/soft//hard///"))
    }

    func testDerivationPathWithoutSoftPredicate() {
        XCTAssertTrue(NSPredicate.deriviationPathWithoutSoft.evaluate(with: "//2///3"))
        XCTAssertTrue(NSPredicate.deriviationPathWithoutSoft.evaluate(with: "//мир//привет///пароль"))
        XCTAssertTrue(NSPredicate.deriviationPathWithoutSoft.evaluate(with: "///пароль"))
        XCTAssertTrue(NSPredicate.deriviationPathWithoutSoft.evaluate(with: "//hard"))
        XCTAssertTrue(NSPredicate.deriviationPathWithoutSoft.evaluate(with: ""))

        XCTAssertFalse(NSPredicate.deriviationPathWithoutSoft.evaluate(with: "soft"))
        XCTAssertFalse(NSPredicate.deriviationPathWithoutSoft.evaluate(with: "/soft"))
        XCTAssertFalse(NSPredicate.deriviationPathWithoutSoft.evaluate(with: "//hard/soft"))
        XCTAssertFalse(NSPredicate.deriviationPathWithoutSoft.evaluate(with: "//hard/soft///password"))
        XCTAssertFalse(NSPredicate.deriviationPathWithoutSoft.evaluate(with: "/soft//"))
        XCTAssertFalse(NSPredicate.deriviationPathWithoutSoft.evaluate(with: "////hard"))
        XCTAssertFalse(NSPredicate.deriviationPathWithoutSoft.evaluate(with: "/soft//hard///"))
    }

}
