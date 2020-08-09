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

    func testSeedPredicate() {
        XCTAssertTrue(NSPredicate.seed.evaluate(with: "2d02848ad2a3fba73321961cd5d1b8272aa95a21e75dd5b098fb36ed996961ac"))
        XCTAssertTrue(NSPredicate.seed.evaluate(with: "0x2d02848ad2a3fba73321961cd5d1b8272aa95a21e75dd5b098fb36ed996961ac"))

        XCTAssertFalse(NSPredicate.seed.evaluate(with: "0x2d02848ad2a3fba73321961cd5d1b8272aa95a21e75dd5b098fb36ed996961"))
        XCTAssertFalse(NSPredicate.seed.evaluate(with: "2d02848ad2a3fba73321961cd5d1b8272aa95a21e75dd5b098fb36ed996961"))
        XCTAssertFalse(NSPredicate.seed.evaluate(with: "2x02848ad2a3fba73321961cd5d1b8272aa95a21e75dd5b098fb36ed99696123"))
        XCTAssertFalse(NSPredicate.seed.evaluate(with: ""))
    }
}
