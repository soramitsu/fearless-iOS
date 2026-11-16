import BigInt
import Foundation
import RobinHood
import SoraFoundation
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import UIKit
import XCTest
@testable import fearless

/// Shared fixtures and test doubles for the lane B staking analytics tests.
enum CovBAnFixtures {
    static let stash = "covb-an-stash"

    static var locale: Locale { LocalizationManager.shared.selectedLocale }

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }()

    static func asset(precision: UInt16 = 2) -> AssetModel {
        ChainModelGenerator.generateAssetWithId("covb-an-asset", symbol: "TST", assetPresicion: precision)
    }

    static func chain(explorers: [ChainModel.ExternalApiExplorer]? = nil) -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: "covb-an-" + UUID().uuidString,
            paraId: nil,
            name: "Covbnet",
            xcm: nil,
            nodes: [],
            addressPrefix: 42,
            icon: nil,
            externalApi: explorers.map { ChainModel.ExternalApiSet(explorers: $0) },
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    static func chainAsset(precision: UInt16 = 2, explorers: [ChainModel.ExternalApiExplorer]? = nil) -> ChainAsset {
        ChainAsset(chain: chain(explorers: explorers), asset: asset(precision: precision))
    }

    static func wallet() -> MetaAccountModel {
        AccountGenerator.generateMetaAccount()
    }

    /// A timestamp `daysAgo` days before the start of today, at `hour` o'clock.
    static func timestamp(daysAgo: Int, hour: Int = 10) -> Int64 {
        let startOfToday = calendar.startOfDay(for: Date())
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: startOfToday) ?? startOfToday
        let date = calendar.date(byAdding: .hour, value: hour, to: day) ?? day
        return Int64(date.timeIntervalSince1970)
    }

    static func reward(
        _ eventId: String,
        daysAgo: Int,
        amount: BigUInt,
        isReward: Bool = true,
        validator: AccountAddress = "",
        stash: AccountAddress = CovBAnFixtures.stash
    ) -> SubqueryRewardItemData {
        SubqueryRewardItemData(
            eventId: eventId,
            timestamp: timestamp(daysAgo: daysAgo),
            validatorAddress: validator,
            era: 0,
            stashAddress: stash,
            amount: amount,
            isReward: isReward
        )
    }

    static func stakeChange(
        _ eventId: String,
        daysAgo: Int,
        amount: BigUInt,
        accumulated: BigUInt,
        type: String
    ) throws -> SubqueryStakeChangeData {
        let json = JSON.dictionaryValue([
            "id": .stringValue(eventId),
            "timestamp": .stringValue(String(timestamp(daysAgo: daysAgo))),
            "address": .stringValue(stash),
            "amount": .stringValue(String(amount)),
            "accumulatedAmount": .stringValue(String(accumulated)),
            "type": .stringValue(type)
        ])
        return try XCTUnwrap(SubqueryStakeChangeData(from: json))
    }

    static func nomination(targets: [Data], submittedIn: UInt32 = 0) throws -> Nomination {
        let payload: [String: Any] = [
            "targets": targets.map { $0.toHex(includePrefix: true) },
            "submittedIn": String(submittedIn)
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(Nomination.self, from: data)
    }

    static func eraInfo(address: AccountAddress, era: EraIndex) throws -> SubqueryEraValidatorInfo {
        let json = JSON.dictionaryValue([
            "address": .stringValue(address),
            "era": .unsignedIntValue(UInt64(era))
        ])
        return try XCTUnwrap(SubqueryEraValidatorInfo(from: json))
    }

    static func priceData(_ price: String = "2") -> PriceData {
        PriceData(currencyId: "usd", priceId: "covb-an", price: price, fiatDayChange: nil, coingeckoPriceId: nil)
    }

    /// Hosts a controller in an iPhone-sized window and lays it out. The window joins the host app's scene when one is
    /// connected; a simulator that never connected the scene still lays the controller out in a detached window.
    static func host(_ controller: UIViewController) -> UIWindow {
        let frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map(UIWindow.init(windowScene:)) ?? UIWindow(frame: frame)
        window.frame = frame
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()
        return window
    }

    /// Spins the main run loop until `condition` holds or `timeout` elapses; returns the final value.
    @discardableResult
    static func spin(timeout: TimeInterval = 5, until condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            if condition() { return true }
            if Date() > deadline { return condition() }
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
    }

    static func allSubviews<T: UIView>(of type: T.Type, in view: UIView) -> [T] {
        view.subviews.flatMap { subview -> [T] in
            let match = (subview as? T).map { [$0] } ?? []
            return match + allSubviews(of: type, in: subview)
        }
    }
}

struct CovBAnError: Error, Equatable {
    let code: Int
}

final class CovBAnIdentityFactoryStub: IdentityOperationFactoryProtocol {
    var result: Result<[AccountAddress: AccountIdentity], Error>
    private(set) var requestedIds: [[AccountId]] = []

    init(result: Result<[AccountAddress: AccountIdentity], Error>) {
        self.result = result
    }

    func createIdentityWrapper(
        for accountIdClosure: @escaping () throws -> [AccountId],
        engine _: JSONRPCEngine,
        runtimeService _: RuntimeCodingServiceProtocol,
        chain _: ChainModel
    ) -> CompoundOperationWrapper<[AccountAddress: AccountIdentity]> {
        requestedIds.append((try? accountIdClosure()) ?? [])
        let result = self.result
        let operation = ClosureOperation<[AccountAddress: AccountIdentity]> { try result.get() }
        return CompoundOperationWrapper(targetOperation: operation)
    }
}

final class CovBAnFixturesTests: XCTestCase {
    func testTimestampsFallOnTheRequestedDayBeforeToday() {
        let calendar = CovBAnFixtures.calendar
        let date = Date(timeIntervalSince1970: TimeInterval(CovBAnFixtures.timestamp(daysAgo: 3, hour: 5)))
        let expectedDay = calendar.date(byAdding: .day, value: -3, to: calendar.startOfDay(for: Date()))
        XCTAssertEqual(calendar.startOfDay(for: date), expectedDay)
        XCTAssertEqual(calendar.component(.hour, from: date), 5)
    }

    func testStakeChangeFixtureDecodesEveryField() throws {
        let change = try CovBAnFixtures.stakeChange("e1", daysAgo: 1, amount: 30, accumulated: 70, type: "unbonded")
        XCTAssertEqual(change.eventId, "e1")
        XCTAssertEqual(change.amount, 30)
        XCTAssertEqual(change.accumulatedAmount, 70)
        XCTAssertEqual(change.type, .unbonded)
        XCTAssertEqual(change.address, CovBAnFixtures.stash)
    }
}
