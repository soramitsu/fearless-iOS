import XCTest
import SSFModels
import SoraFoundation
import BigInt
@testable import fearless

// Shared fixtures and hand-written doubles for the CovCPJ (pool create / join) test files.

enum CovCPJTestError: Error {
    case failed
}

enum CovCPJFixtures {
    static let locale = Locale(identifier: "en")
    static let languages = ["en"]

    static func chainAsset(precision: UInt16 = 10, symbol: String = "dot") -> ChainAsset {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: symbol, assetPresicion: precision)
        return ChainAsset(chain: chain, asset: asset)
    }

    static func wallet() -> fearless.MetaAccountModel {
        AccountGenerator.generateMetaAccount()
    }

    static func localizationManager() throws -> LocalizationManagerProtocol {
        try XCTUnwrap(LocalizationManager(localization: "en"))
    }

    static func balanceFactory(
        chainAsset: ChainAsset,
        wallet: fearless.MetaAccountModel
    ) -> BalanceViewModelFactory {
        BalanceViewModelFactory(targetAssetInfo: chainAsset.assetDisplayInfo, selectedMetaAccount: wallet)
    }

    static func roles(
        depositor: AccountId = Data(repeating: 1, count: 32),
        root: AccountId? = nil,
        nominator: AccountId? = nil,
        bouncer: AccountId? = nil
    ) -> StakingPoolRoles {
        StakingPoolRoles(depositor: depositor, root: root, nominator: nominator, bouncer: bouncer)
    }

    static func pool(
        id: String,
        name: String,
        points: BigUInt,
        members: UInt32,
        state: StakingPoolState = .open
    ) -> StakingPool {
        let info = StakingPoolInfo(points: points, state: state, memberCounter: members, roles: roles())
        return StakingPool(id: id, info: info, name: name)
    }

    static func accountInfo(free: BigUInt, frozen: BigUInt = 0) -> AccountInfo {
        AccountInfo(
            nonce: 0,
            consumers: 0,
            providers: 0,
            data: AccountData(free: free, reserved: 0, frozen: frozen)
        )
    }

    static func poolMember(poolId: UInt32, points: String, rewardCounter: String = "0") throws -> StakingPoolMember {
        let json = """
        {"poolId":"\(poolId)","points":"\(points)","lastRecordedRewardCounter":"\(rewardCounter)","unbondingEras":[]}
        """
        return try JSONDecoder().decode(StakingPoolMember.self, from: Data(json.utf8))
    }

    static func nomination(targetCount: Int) throws -> Nomination {
        let targets = Array(repeating: "\"AQIDBA==\"", count: targetCount).joined(separator: ",")
        let json = "{\"targets\":[\(targets)],\"submittedIn\":\"5\"}"
        return try JSONDecoder().decode(Nomination.self, from: Data(json.utf8))
    }

    static func price(_ value: String) -> PriceData {
        PriceData(currencyId: "usd", priceId: "dot", price: value, fiatDayChange: nil, coingeckoPriceId: nil)
    }

    static func spin(timeout: TimeInterval = 2, until condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    static func labelTexts(in view: UIView) -> [String] {
        var result: [String] = []
        if let label = view as? UILabel, let text = label.text ?? label.attributedText?.string {
            result.append(text)
        }
        for subview in view.subviews {
            result.append(contentsOf: labelTexts(in: subview))
        }
        return result
    }

    static func host(_ controller: UIViewController) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        return window
    }
}

final class CovCPJLoggerDouble: LoggerProtocol {
    private(set) var errors: [String] = []

    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}

    func error(message: String, file _: String, function _: String, line _: Int) {
        errors.append(message)
    }

    func customError(error: Error, file _: String, function _: String, line _: Int) {
        errors.append("\(error)")
    }
}

final class CovCPJAuthorizerDouble: SubmissionAuthorizing {
    var authorized = true
    private(set) var requests = 0

    func authorizeSubmission(from _: ControllerBackedProtocol?, completion: @escaping (Bool) -> Void) {
        requests += 1
        completion(authorized)
    }
}

final class CovCPJValidationViewDouble: ControllerBackedProtocol, Localizable {
    let controller = UIViewController()
    var isSetup: Bool { true }

    func applyLocalization() {}
}

/// Records the presentation calls shared by the pool routers. Subclasses add the router's own protocol, and the
/// inherited methods take precedence over the protocol-extension defaults that would present real sheets.
class CovCPJPresentableRecorder {
    var presentErrorResult = false

    private(set) var dismissCount = 0
    private(set) var presentedErrors: [Error] = []
    private(set) var sheetViewModels: [SheetAlertPresentableViewModel] = []
    private(set) var extrinsicFailedCount = 0
    private(set) var amountTooLowValues: [String] = []
    private(set) var feeNotReceivedCount = 0
    private(set) var amountTooHighCount = 0
    private(set) var missingPoolNameCount = 0
    private(set) var maximumPoolsReachedCount = 0
    private(set) var existentialDepositWarnings: [String] = []
    private(set) var existentialDepositActions: [() -> Void] = []
    private(set) var existentialDepositErrors: [String] = []
    private(set) var successNotifications: [String] = []
    private(set) var shownWebURLs: [URL] = []

    func dismiss(view _: ControllerBackedProtocol?) {
        dismissCount += 1
    }

    @discardableResult
    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        presentedErrors.append(error)
        return presentErrorResult
    }

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {
        sheetViewModels.append(viewModel)
    }

    func presentExtrinsicFailed(from _: ControllerBackedProtocol, locale _: Locale?) {
        extrinsicFailedCount += 1
    }

    func presentAmountTooLow(value: String, from _: ControllerBackedProtocol, locale _: Locale?) {
        amountTooLowValues.append(value)
    }

    func presentFeeNotReceived(from _: ControllerBackedProtocol, locale _: Locale?) {
        feeNotReceivedCount += 1
    }

    func presentAmountTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) {
        amountTooHighCount += 1
    }

    func presentMissingPoolName(from _: ControllerBackedProtocol?, locale _: Locale?) {
        missingPoolNameCount += 1
    }

    func presentMaximumPoolsCountReached(from _: ControllerBackedProtocol?, locale _: Locale?) {
        maximumPoolsReachedCount += 1
    }

    func presentExistentialDepositWarning(
        existentianDepositValue: String,
        from _: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale _: Locale?
    ) {
        existentialDepositWarnings.append(existentianDepositValue)
        existentialDepositActions.append(action)
    }

    func presentExistentialDepositError(
        existentianDepositValue: String,
        from _: ControllerBackedProtocol,
        locale _: Locale?
    ) {
        existentialDepositErrors.append(existentianDepositValue)
    }

    func presentSuccessNotification(
        _ title: String,
        from _: ControllerBackedProtocol?,
        completion _: (() -> Void)?
    ) {
        successNotifications.append(title)
    }

    func showWeb(url: URL, from _: ControllerBackedProtocol, style _: WebPresentableStyle) {
        shownWebURLs.append(url)
    }
}

final class CovCPJSupportTests: XCTestCase {
    func testFixturesBuildConsistentModels() throws {
        let member = try CovCPJFixtures.poolMember(poolId: 7, points: "1000", rewardCounter: "3")
        XCTAssertEqual(member.poolId.value, 7)
        XCTAssertEqual(member.points, BigUInt(1000))
        XCTAssertEqual(member.lastRecordedRewardCounter, BigUInt(3))

        let nomination = try CovCPJFixtures.nomination(targetCount: 2)
        XCTAssertEqual(nomination.targets.count, 2)
        XCTAssertTrue(try CovCPJFixtures.nomination(targetCount: 0).targets.isEmpty)

        let pool = CovCPJFixtures.pool(id: "3", name: "Pool", points: 10, members: 2)
        XCTAssertEqual(pool.info.memberCounter, 2)
        XCTAssertEqual(CovCPJFixtures.accountInfo(free: 10, frozen: 4).data.stakingAvailable, BigUInt(6))
    }
}
