import XCTest
import BigInt
import SSFModels
import SSFUtils
import SoraFoundation
@testable import fearless

// Shared fixtures and hand-written doubles for the unbond / redeem / rebond coverage tests.

enum CovCUBFixture {
    static let precision: UInt16 = 10
    static let english = Locale(identifier: "en")

    static func planks(_ value: Decimal) -> BigUInt {
        value.toSubstrateAmount(precision: Int16(precision)) ?? .zero
    }

    static func asset(color: String? = nil) -> AssetModel {
        AssetModel(
            id: "dot",
            name: "DOT",
            symbol: "dot",
            precision: precision,
            icon: nil,
            currencyId: nil,
            existentialDeposit: nil,
            color: color,
            isUtility: true,
            isNative: true,
            staking: nil,
            purchaseProviders: nil,
            type: nil,
            ethereumType: nil,
            priceProvider: nil,
            coingeckoPriceId: nil
        )
    }

    static func chainAsset(color: String? = nil) -> ChainAsset {
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 0,
            assetPresicion: precision
        )
        return ChainAsset(chain: chain, asset: asset(color: color))
    }

    static func wallet() -> fearless.MetaAccountModel {
        AccountGenerator.generateMetaAccount()
    }

    static func account(
        for chainAsset: ChainAsset,
        wallet: fearless.MetaAccountModel
    ) throws -> fearless.ChainAccountResponse {
        try XCTUnwrap(wallet.fetch(for: chainAsset.chain.accountRequest()))
    }

    static func address(for chainAsset: ChainAsset, wallet: fearless.MetaAccountModel) throws -> String {
        try XCTUnwrap(account(for: chainAsset, wallet: wallet).toAddress())
    }

    static func stashItem(controller: String) -> StashItem {
        StashItem(stash: controller, controller: controller)
    }

    static func accountInfo(free: Decimal, frozen: Decimal = 0) -> AccountInfo {
        AccountInfo(
            nonce: 1,
            consumers: 0,
            providers: 1,
            data: AccountData(free: planks(free), reserved: .zero, frozen: planks(frozen))
        )
    }

    static func dispatchInfo(fee: Decimal) -> fearless.RuntimeDispatchInfo {
        fearless.RuntimeDispatchInfo(feeValue: planks(fee))
    }

    static func ledger(active: Decimal, unlocking: [(Decimal, UInt32)] = []) throws -> StakingLedger {
        let payload: [String: Any] = [
            "stash": Data(repeating: 1, count: 32).toHex(includePrefix: true),
            "total": String(planks(active + unlocking.reduce(Decimal(0)) { $0 + $1.0 })),
            "active": String(planks(active)),
            "unlocking": unlocking.map { ["value": String(planks($0.0)), "era": String($0.1)] },
            "claimedRewards": []
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(StakingLedger.self, from: data)
    }

    static func poolMember(points: Decimal, unbonding: [(Decimal, UInt32)] = []) throws -> StakingPoolMember {
        let payload: [String: Any] = [
            "poolId": "7",
            "points": String(planks(points)),
            "lastRecordedRewardCounter": "0",
            "unbondingEras": unbonding.map { ["value": String(planks($0.0)), "era": String($0.1)] }
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(StakingPoolMember.self, from: data)
    }

    static func nomination() throws -> Nomination {
        let payload: [String: Any] = ["targets": [], "submittedIn": "1"]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(Nomination.self, from: data)
    }

    static func slashingSpans(priorCount: Int) throws -> SlashingSpans {
        let payload: [String: Any] = [
            "lastNonzeroSlash": "0",
            "prior": (0 ..< priorCount).map { String($0) }
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(SlashingSpans.self, from: data)
    }

    static func stakingPool(depositor: AccountId) throws -> StakingPool {
        let payload: [String: Any] = [
            "id": "7",
            "name": "Pool",
            "info": [
                "points": "100",
                "state": ["Open"],
                "memberCounter": "1",
                "roles": ["depositor": depositor.base64EncodedString()]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(StakingPool.self, from: data)
    }

    static func activeEra(_ index: UInt32) -> ActiveEraInfo {
        ActiveEraInfo(index: index)
    }

    static func balanceFactory(wallet: fearless.MetaAccountModel) -> BalanceViewModelFactory {
        BalanceViewModelFactory(targetAssetInfo: asset().displayInfo, selectedMetaAccount: wallet)
    }

    static func validationResults(_ validators: [DataValidating]) -> [DataValidationProblem?] {
        let delegate = CovCUBValidationDelegate()
        return validators.map { $0.validate(notifying: delegate) }
    }
}

enum CovCUBTestError: Error {
    case failed
}

final class CovCUBValidationDelegate: DataValidatingDelegate {
    private(set) var completedWarnings = 0

    func didCompleteWarningHandling() {
        completedWarnings += 1
    }
}

final class CovCUBIconGenerator: IconGenerating {
    private(set) var addresses: [String] = []

    func generateFromAddress(_ address: String) throws -> DrawableIcon {
        addresses.append(address)
        return try PolkadotIconGenerator().generateFromAddress(address)
    }
}

/// Records which extrinsic calls a builder closure adds.
final class CovCUBBuilderSpy: ExtrinsicBuilderProtocol {
    private(set) var callNames: [String] = []

    func with<A: Codable>(address _: A) throws -> Self { self }
    func with(nonce _: UInt32) -> Self { self }
    func with(era _: Era, blockHash _: String) -> Self { self }
    func with(tip _: BigUInt) -> Self { self }
    func with(appId _: BigUInt) -> Self { self }
    func with(shouldUseAtomicBatch _: Bool) -> Self { self }

    func adding<T: RuntimeCallable>(call: T) throws -> Self {
        callNames.append(call.callName)
        return self
    }

    func adding(rawCall _: Data) throws -> Self { self }

    func signing(
        by _: (Data) throws -> Data,
        of _: CryptoType,
        using _: DynamicScaleEncoding,
        metadata _: RuntimeMetadata
    ) throws -> Self { self }

    func build(encodingBy _: DynamicScaleEncoding, metadata _: RuntimeMetadata) throws -> Data { Data() }

    func buildSignature(encodingBy _: DynamicScaleEncoding, metadata _: RuntimeMetadata) throws -> Data { Data() }

    static func callNames(of closure: ExtrinsicBuilderClosure?) throws -> [String] {
        let builder = CovCUBBuilderSpy()
        let closure = try XCTUnwrap(closure)
        _ = try closure(builder)
        return builder.callNames
    }
}

/// Returns plain runtime calls named after the call-factory method, so builder closures can be inspected.
final class CovCUBCallFactoryStub: SubstrateCallFactoryProtocol {
    private(set) var requested: [String] = []

    private func call(_ name: String) -> RuntimeCall<NoRuntimeArgs> {
        requested.append(name)
        return RuntimeCall(moduleName: "Staking", callName: name)
    }

    func transfer(to _: AccountId, amount _: BigUInt, chainAsset _: ChainAsset) -> any RuntimeCallable { call("transfer") }
    func transfer(to _: AccountId, amount _: BigUInt) -> any RuntimeCallable { call("transfer") }
    func xorlessTransfer(_: XorlessTransfer) -> any RuntimeCallable { call("xorless_transfer") }
    func bond(
        amount _: BigUInt,
        controller _: String,
        rewardDestination _: RewardDestination<AccountAddress>,
        chainAsset _: ChainAsset
    ) throws -> any RuntimeCallable { call("bond") }
    func bondExtra(amount _: BigUInt) -> any RuntimeCallable { call("bond_extra") }
    func unbond(amount _: BigUInt) -> any RuntimeCallable { call("unbond") }
    func rebond(amount _: BigUInt) -> any RuntimeCallable { call("rebond") }
    func nominate(targets _: [SelectedValidatorInfo], chainAsset _: ChainAsset) throws -> any RuntimeCallable { call("nominate") }
    func poolNominate(poolId _: UInt32, targets _: [SelectedValidatorInfo]) throws -> any RuntimeCallable { call("pool_nominate") }
    func payout(validatorId _: Data, era _: EraIndex) throws -> any RuntimeCallable { call("payout_stakers") }
    func setPayee(for _: RewardDestinationArg) -> any RuntimeCallable { call("set_payee") }
    func withdrawUnbonded(for _: UInt32) -> any RuntimeCallable { call("withdraw_unbonded") }
    func setController(_: AccountAddress, chainAsset _: ChainAsset) throws -> any RuntimeCallable { call("set_controller") }
    func chill() -> any RuntimeCallable { call("chill") }
    func contribute(to _: ParaId, amount _: BigUInt, multiSignature _: MultiSignature?) -> any RuntimeCallable { call("contribute") }
    func addMemo(to _: ParaId, memo _: Data) -> any RuntimeCallable { call("add_memo") }
    func addRemark(_: Data) -> any RuntimeCallable { call("remark") }
    func joinPool(poolId _: String, amount _: BigUInt) -> any RuntimeCallable { call("join") }
    func createPool(
        amount _: BigUInt,
        root _: MultiAddress,
        nominator _: MultiAddress,
        bouncer _: MultiAddress
    ) throws -> any RuntimeCallable { call("create") }
    func setPoolMetadata(poolId _: String, metadata _: Data) -> any RuntimeCallable { call("set_metadata") }
    func poolBondMore(amount _: BigUInt) -> any RuntimeCallable { call("bond_extra") }
    func poolUnbond(accountId _: AccountId, amount _: BigUInt) -> any RuntimeCallable { call("pool_unbond") }
    func claimPoolRewards() -> any RuntimeCallable { call("claim_payout") }
    func poolWithdrawUnbonded(accountId _: AccountId, numSlashingSpans _: UInt32) -> any RuntimeCallable {
        call("pool_withdraw_unbonded")
    }

    func nominationPoolUpdateRoles(poolId _: String, roles _: StakingPoolRoles) -> any RuntimeCallable { call("update_roles") }
    func swap(
        dexId _: String,
        from _: String,
        to _: String,
        amountCall _: [SwapVariant: SwapAmount],
        type _: [[String?]],
        filter _: Int
    ) -> any RuntimeCallable { call("swap") }
    func poolUnbondOld(accountId _: AccountId, amount _: BigUInt) -> any RuntimeCallable { call("pool_unbond_old") }
    func setRewardDestination(
        _: RewardDestination<AccountAddress>,
        stashItem _: StashItem,
        chainAsset _: ChainAsset
    ) throws -> any RuntimeCallable { call("set_reward_destination") }
    func vestingClaim() throws -> any RuntimeCallable { call("vest") }
}

/// Records the staking error alerts that validators present.
final class CovCUBStakingErrorSpy: StakingErrorPresentable, SheetAlertPresentable, ErrorPresentable {
    private(set) var presented: [String] = []

    func present(viewModel _: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {
        presented.append("sheet")
    }

    func present(
        message _: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {
        presented.append("message")
    }

    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) {
        presented.append("info")
    }

    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        presented.append("error")
        return true
    }

    func dismiss(view _: ControllerBackedProtocol?) {
        presented.append("dismiss")
    }

    func presentUnbondingTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) {
        presented.append("unbondingTooHigh")
    }

    func presentRebondingTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) {
        presented.append("rebondingTooHigh")
    }

    func presentFeeNotReceived(from _: ControllerBackedProtocol, locale _: Locale?) {
        presented.append("feeNotReceived")
    }

    func presentFeeTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) {
        presented.append("feeTooHigh")
    }

    func presentMissingController(from _: ControllerBackedProtocol, address _: AccountAddress, locale _: Locale?) {
        presented.append("missingController")
    }

    func presentNoRedeemables(from _: ControllerBackedProtocol?, locale _: Locale?) {
        presented.append("noRedeemables")
    }

    func presentStashKilledAfterUnbond(from _: ControllerBackedProtocol, action: @escaping () -> Void, locale _: Locale?) {
        presented.append("stashKilled")
        action()
    }

    func presentPoolRootUnbondingTooHigh(minimalBond _: String, from _: ControllerBackedProtocol, locale _: Locale?) {
        presented.append("poolRootUnbondingTooHigh")
    }
}

/// A minimal view the validating factory can present from.
final class CovCUBValidationView: ControllerBackedProtocol, Localizable {
    let controller = UIViewController()
    var isSetup: Bool { true }

    func applyLocalization() {}
}

final class CovCUBLoggerSpy: fearless.LoggerProtocol {
    private(set) var errors: [String] = []
    private(set) var warnings: [String] = []

    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message: String, file _: String, function _: String, line _: Int) { warnings.append(message) }
    func error(message: String, file _: String, function _: String, line _: Int) { errors.append(message) }
    func customError(error: Error, file _: String, function _: String, line _: Int) { errors.append("\(error)") }
}

final class CovCUBAuthorizer: SubmissionAuthorizing {
    var authorizes: Bool
    private(set) var requests = 0

    init(authorizes: Bool) {
        self.authorizes = authorizes
    }

    func authorizeSubmission(from _: ControllerBackedProtocol?, completion: @escaping (Bool) -> Void) {
        requests += 1
        completion(authorizes)
    }
}
