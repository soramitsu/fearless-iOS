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

/// Shared fixtures for coverage lane A (select validators flow and staking main).
enum CovAFixtures {
    static let locale = Locale(identifier: "en")
    /// The shared manager follows the simulator app's saved language; tests pin English.
    static let localizationManager: LocalizationManager = LocalizationManager(localization: "en") ?? LocalizationManager.shared
    static let chainId = "cov-a-relay-chain"

    static func address(_ seed: UInt8) -> AccountAddress {
        do {
            return try Data(repeating: seed, count: 32).toAddress(using: .substrate(42))
        } catch {
            XCTFail("Could not encode fixture address: \(error)")
            return ""
        }
    }

    static func accountId(_ seed: UInt8) -> AccountId {
        Data(repeating: seed, count: 32)
    }

    static func asset(
        staking: RawStakingType? = .relayChain,
        precision: UInt16 = 12,
        price: Decimal? = nil
    ) -> AssetModel {
        AssetModel(
            id: "cov-a-asset",
            name: "Cov Token",
            symbol: "COV",
            precision: precision,
            price: price,
            currencyId: "usd",
            existentialDeposit: "1000000000",
            isUtility: true,
            isNative: true,
            staking: staking
        )
    }

    static func chainAsset(
        staking: RawStakingType? = .relayChain,
        chainId: String = chainId,
        price: Decimal? = nil,
        options: [ChainOptions]? = nil
    ) -> ChainAsset {
        let token = asset(staking: staking, price: price)
        let chain = ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: "Cov Relay",
            assets: [token],
            xcm: nil,
            nodes: [],
            addressPrefix: 42,
            icon: nil,
            options: options,
            iosMinAppVersion: nil,
            identityChain: nil
        )
        return ChainAsset(chain: chain, asset: token)
    }

    static func wallet(accountSeed: UInt8 = 7) -> MetaAccountModel {
        MetaAccountModel(
            metaId: "cov-a-wallet",
            name: "Cov wallet",
            substrateAccountId: accountId(accountSeed),
            substrateCryptoType: 0,
            substratePublicKey: accountId(accountSeed),
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [],
            assetKeysOrder: nil,
            canExportEthereumMnemonic: false,
            unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(),
            networkManagmentFilter: nil,
            assetsVisibility: [],
            hasBackup: true,
            favouriteChainIds: []
        )
    }

    static func balanceFactory(
        chainAsset: ChainAsset = chainAsset(),
        wallet: MetaAccountModel = wallet()
    ) -> BalanceViewModelFactory {
        BalanceViewModelFactory(targetAssetInfo: chainAsset.asset.displayInfo, selectedMetaAccount: wallet)
    }

    static func chainData(_ text: String) -> ChainData {
        .raw(data: Data(text.utf8))
    }

    static func identity(name: String = "Validator One", full: Bool = true, parent: String? = nil) -> AccountIdentity {
        let info = IdentityInfo(
            additional: nil,
            display: chainData(name),
            legal: full ? chainData("Legal Name") : nil,
            web: full ? chainData("https://validator.example") : nil,
            riot: full ? chainData("@validator:matrix.org") : nil,
            email: full ? chainData("validator@example.com") : nil,
            image: nil,
            twitter: full ? chainData("@validator") : nil
        )
        return AccountIdentity(name: name, parentAddress: parent.map { _ in address(99) }, parentName: parent, identity: info)
    }

    static func stakeInfo(
        nominatorStakes: [Decimal] = [10, 20, 30],
        total: Decimal = 100,
        stakeReturn: Decimal = 0.15,
        maxNominatorsRewarded: UInt32? = 2
    ) -> ValidatorStakeInfo {
        let nominators = nominatorStakes.enumerated().map { index, stake in
            NominatorInfo(address: address(UInt8(100 + index)), stake: stake)
        }
        return ValidatorStakeInfo(
            nominators: nominators,
            totalStake: total,
            stakeReturn: stakeReturn,
            maxNominatorsRewarded: maxNominatorsRewarded
        )
    }

    static func validator(
        _ seed: UInt8,
        identity: AccountIdentity? = nil,
        stakeInfo: ValidatorStakeInfoProtocol? = stakeInfo(),
        myNomination: ValidatorMyNominationStatus? = nil,
        commission: Decimal = 0.05,
        hasSlashes: Bool = false,
        blocked: Bool = false,
        elected: Bool = true
    ) -> SelectedValidatorInfo {
        SelectedValidatorInfo(
            address: address(seed),
            identity: identity,
            stakeInfo: stakeInfo,
            myNomination: myNomination,
            commission: commission,
            hasSlashes: hasSlashes,
            blocked: blocked,
            elected: elected
        )
    }

    static func electedValidator(
        _ seed: UInt8,
        identity: AccountIdentity? = nil,
        stakeReturn: Decimal = 0.1,
        totalStake: Decimal = 1000,
        ownStake: Decimal = 100,
        commission: Decimal = 0.05,
        hasSlashes: Bool = false,
        oversubscribed _: Bool = false,
        blocked: Bool = false,
        nominatorCount: Int = 3
    ) -> ElectedValidatorInfo {
        let nominators = (0 ..< nominatorCount).map { NominatorInfo(address: address(UInt8(150 + $0)), stake: 10) }
        return ElectedValidatorInfo(
            address: address(seed),
            nominators: nominators,
            totalStake: totalStake,
            ownStake: ownStake,
            comission: commission,
            identity: identity,
            stakeReturn: stakeReturn,
            hasSlashes: hasSlashes,
            maxNominatorsRewarded: 256,
            blocked: blocked,
            elected: true
        )
    }
}

/// A view-hierarchy inspection helper.
enum CovAViewInspector {
    static func labels(in view: UIView) -> [String] {
        var result: [String] = []
        if let label = view as? UILabel, let text = label.text, !text.isEmpty {
            result.append(text)
        }
        if let field = view as? UITextField, let text = field.text, !text.isEmpty {
            result.append(text)
        }
        for subview in view.subviews {
            result.append(contentsOf: labels(in: subview))
        }
        return result
    }

    static func subviews<T: UIView>(of _: T.Type, in view: UIView) -> [T] {
        var result: [T] = []
        if let match = view as? T {
            result.append(match)
        }
        for subview in view.subviews {
            result.append(contentsOf: subviews(of: T.self, in: subview))
        }
        return result
    }

    static func contains(_ text: String, in view: UIView) -> Bool {
        labels(in: view).contains { $0.contains(text) }
    }

    @discardableResult
    static func host(_ controller: UIViewController) -> UIWindow {
        let window: UIWindow
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window = UIWindow(windowScene: scene)
        } else {
            XCTFail("The test host must have a window scene")
            window = UIWindow()
        }
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()
        return window
    }

    static func spin(until condition: () -> Bool, timeout: TimeInterval = 5) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }
}

/// A validator operation factory that answers at once with fixed results.
final class CovAValidatorOperationFactoryStub: ValidatorOperationFactoryProtocol {
    var nominationResult: Nomination?
    var electedResult: [ElectedValidatorInfo] = []
    var selectedResult: [SelectedValidatorInfo] = []
    var error: Error?
    private(set) var wannabeRequests: [[AccountId]] = []
    private(set) var activeRequests: [AccountAddress] = []
    private(set) var pendingRequests: [[AccountId]] = []

    private func wrapper<T>(_ value: T) -> CompoundOperationWrapper<T> {
        let error = self.error
        let operation = ClosureOperation<T> {
            if let error = error {
                throw error
            }
            return value
        }
        return CompoundOperationWrapper(targetOperation: operation)
    }

    func nomination(accountId _: AccountId) -> CompoundOperationWrapper<Nomination?> {
        wrapper(nominationResult)
    }

    func fetchAllValidators() -> CompoundOperationWrapper<[ElectedValidatorInfo]> {
        wrapper(electedResult)
    }

    func allElectedOperation() -> CompoundOperationWrapper<[ElectedValidatorInfo]> {
        wrapper(electedResult)
    }

    func allSelectedOperation(
        by _: Nomination,
        nominatorAddress _: AccountAddress
    ) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        wrapper(selectedResult)
    }

    func activeValidatorsOperation(for nominatorAddress: AccountAddress) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        activeRequests.append(nominatorAddress)
        return wrapper(selectedResult)
    }

    func pendingValidatorsOperation(for accountIds: [AccountId]) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        pendingRequests.append(accountIds)
        return wrapper(selectedResult)
    }

    func wannabeValidatorsOperation(for accountIdList: [AccountId]) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        wannabeRequests.append(accountIdList)
        return wrapper(selectedResult)
    }
}

enum CovATestError: Error {
    case failed
}

/// An account-info adapter that records subscriptions and answers when told to.
final class CovAAccountInfoAdapterStub: AccountInfoSubscriptionAdapterProtocol {
    private(set) var subscribedAccountIds: [AccountId] = []
    private(set) var subscribedChainAssets: [ChainAsset] = []
    private(set) var resetCount = 0
    private(set) var unsubscribed: [ChainAsset] = []
    private(set) var wallets: [MetaAccountModel] = []
    weak var handler: AccountInfoSubscriptionAdapterHandler?

    func subscribe(
        chainAsset: ChainAsset,
        accountId: AccountId,
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn _: DispatchQueue?,
        notifyJustWhenUpdated _: Bool
    ) {
        subscribedAccountIds.append(accountId)
        subscribedChainAssets.append(chainAsset)
        self.handler = handler
    }

    func subscribe(
        chainsAssets: [ChainAsset],
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn _: DispatchQueue?,
        notifyJustWhenUpdated _: Bool
    ) {
        subscribedChainAssets.append(contentsOf: chainsAssets)
        self.handler = handler
    }

    func reset() {
        resetCount += 1
    }

    func unsubscribe(chainAsset: ChainAsset) {
        unsubscribed.append(chainAsset)
    }

    func update(wallet: MetaAccountModel) {
        wallets.append(wallet)
    }
}

/// A runtime coding service that never yields a coder factory (for factories that only need the dependency).
final class CovARuntimeCodingServiceStub: RuntimeProviderProtocol {
    var snapshot: RuntimeSnapshot? {
        nil
    }

    var runtimeSpecVersion: RuntimeSpecVersion {
        .defaultVersion
    }

    func setup() {}
    func setupHot() {}
    func cleanup() {}
    func readySnapshot() async throws -> RuntimeSnapshot {
        throw CovATestError.failed
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { throw CovATestError.failed }
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        throw CovATestError.failed
    }
}
