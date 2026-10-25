//import XCTest
//@testable import fearless
//import SoraFoundation
//import SoraKeystore
//import IrohaCrypto
//import RobinHood
//import Cuckoo
//
//class StakingPayoutsConfirmTests: XCTestCase {
//    func testSetupAndSendExtrinsic() throws {
//        // given
//
//        let address = "5E9W1jho79KwmnwxnGjGaBEyWw9XFjhu3upEaDtwWSvVgbou"
//        let validatorAccountId = try! SS58AddressFactory().accountId(from: address)
//
//        let settings = InMemorySettingsManager()
//        let keychain = InMemoryKeychain()
//        let chain: Chain = .westend
//
//        let storageFacade = SubstrateStorageTestFacade()
//        let operationManager = OperationManager()
//
//        let addressType = chain.addressType
//        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
//                                                            keychain: keychain,
//                                                            settings: settings)
//
//        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
//        let asset = primitiveFactory.createAssetForAddressType(addressType)
//        let assetId = WalletAssetId(
//            rawValue: asset.identifier
//        )!
//
//        let view = MockStakingPayoutConfirmationViewProtocol()
//        let wireframe = MockStakingPayoutConfirmationWireframeProtocol()
//
//        let balanceViewModelFactory = BalanceViewModelFactory(walletPrimitiveFactory: primitiveFactory,
//                                                              selectedAddressType: addressType,
//                                                              limit: StakingConstants.maxAmount)
//
//        let viewModelFactory = StakingPayoutConfirmViewModelFactory(asset: asset,
//                                                                    balanceViewModelFactory: balanceViewModelFactory)
//
//        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)
//        let presenter = StakingPayoutConfirmationPresenter(balanceViewModelFactory: balanceViewModelFactory,
//                                                           payoutConfirmViewModelFactory: viewModelFactory,
//                                                           dataValidatingFactory: dataValidatingFactory,
//                                                           chain: chain,
//                                                           asset: asset,
//                                                           logger: nil)
//
//        let extrinsicService = ExtrinsicServiceStub.dummy()
//        let signer = try DummySigner(cryptoType: CryptoType.sr25519)
//
//        let providerFactory = SingleValueProviderFactoryStub.westendNominatorStub()
//
//        let runtimeCodingService = try RuntimeCodingServiceStub.createWestendService()
//
//        let substrateProviderFactory = SubstrateDataProviderFactory(facade: storageFacade,
//                                                                    operationManager: operationManager)
//
//        let accountRepository = AccountRepositoryFactory.createRepository(for: UserDataStorageTestFacade())
//
//        let extrinsicOperationFactory = ExtrinsicOperationFactoryStub()
//
//        let interactor = StakingPayoutConfirmationInteractor(
//            singleValueProviderFactory: providerFactory,
//            substrateProviderFactory: substrateProviderFactory,
//            extrinsicOperationFactory: extrinsicOperationFactory,
//            extrinsicService: extrinsicService,
//            runtimeService: runtimeCodingService,
//            signer: signer,
//            accountRepository: accountRepository,
//            operationManager: OperationManager(),
//            logger: Logger.shared,
//            selectedAccount: settings.selectedAccount!,
//            payouts: [PayoutInfo(era: 1000, validator: validatorAccountId, reward: 1, identity: nil)],
//            chain: chain,
//            assetId: assetId
//        )
//
//        presenter.view = view
//        presenter.wireframe = wireframe
//        presenter.interactor = interactor
//        interactor.presenter = presenter
//
//        // when
//
//        let feeExpectation = XCTestExpectation()
//        let viewModelExpectation = XCTestExpectation()
//
//        stub(view) { stub in
//            when(stub).didReceive(feeViewModel: any()).then { viewModel in
//                if viewModel != nil {
//                    feeExpectation.fulfill()
//                }
//            }
//
//            when(stub).didRecieve(viewModel: any()).then {_ in
//                viewModelExpectation.fulfill()
//            }
//
//            when(stub).didStartLoading().thenDoNothing()
//            when(stub).didStopLoading().thenDoNothing()
//
//            when(stub).localizationManager.get.then { LocalizationManager.shared }
//        }
//
//        let completionExpectation = XCTestExpectation()
//
//        stub(wireframe) { stub in
//            when(stub).complete(from: any()).then { _ in
//                completionExpectation.fulfill()
//            }
//
//            when(stub).present(
//                message: any(),
//                title: any(),
//                closeAction: any(),
//                from: any()).thenDoNothing()
//        }
//
//        // when
//
//        presenter.setup()
//
//        // then
//
//        wait(for: [feeExpectation, viewModelExpectation], timeout: Constants.defaultExpectationDuration)
//
//        // when
//
//        presenter.proceed()
//
//        // then
//
//        wait(for: [completionExpectation], timeout: Constants.defaultExpectationDuration)
//    }
//}

import XCTest
import BigInt
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
@testable import fearless

final class StakingPayoutCurrencyTests: XCTestCase {
    func testRewardWarningComparesValueInFeeAsset() throws {
        let fixture = try makeFixture(reward: 100)
        fixture.cachePrice(asset: fixture.rewardAsset.asset, price: "0.01")
        fixture.cachePrice(asset: fixture.feeAsset.asset, price: "10")
        fixture.state.fee = 1
        XCTAssertFalse(try rewardCondition(fixture.state))
        fixture.cachePrice(asset: fixture.rewardAsset.asset, price: "2")
        XCTAssertTrue(try rewardCondition(fixture.state))
    }

    func testMissingOrWrongCurrencyPriceNeverAssumesOneToOneRate() throws {
        let fixture = try makeFixture(reward: 100)
        fixture.state.fee = 1
        fixture.cachePrice(asset: fixture.rewardAsset.asset, price: "2")
        fixture.cachePrice(asset: fixture.feeAsset.asset, price: "10", currency: "unrelated-currency")
        XCTAssertFalse(try rewardCondition(fixture.state))
    }

    func testZeroFeeAssetPriceDoesNotDivideByZeroOrSuppressWarning() throws {
        let fixture = try makeFixture(reward: 100)
        fixture.state.fee = 1
        fixture.cachePrice(asset: fixture.rewardAsset.asset, price: "2")
        fixture.cachePrice(asset: fixture.feeAsset.asset, price: "0")
        XCTAssertFalse(try rewardCondition(fixture.state))
    }

    func testUtilityRewardDoesNotRequireFiatPrices() throws {
        let fixture = try makeFixture(reward: 2, utilityReward: true)
        fixture.state.fee = 1
        XCTAssertTrue(try rewardCondition(fixture.state))
    }

    func testFeeAffordabilityUsesUtilityBalanceAndPrecision() throws {
        let fixture = try makeFixture(reward: 100)
        fixture.state.fee = 1
        fixture.state.didReceiveAccountInfo(
            result: .success(AccountInfo(ethBalance: BigUInt(2_000_000))),
            chainAsset: fixture.feeAsset
        )
        XCTAssertTrue(try balanceCondition(fixture.state))
        fixture.state.didReceiveAccountInfo(
            result: .success(AccountInfo(ethBalance: .zero)),
            chainAsset: fixture.rewardAsset
        )
        XCTAssertTrue(try balanceCondition(fixture.state))
        fixture.state.didReceiveAccountInfo(
            result: .success(AccountInfo(ethBalance: BigUInt(500_000))),
            chainAsset: fixture.feeAsset
        )
        XCTAssertFalse(try balanceCondition(fixture.state))
    }

    func testFailedUtilityBalanceRefreshInvalidatesPreviousAffordability() throws {
        let fixture = try makeFixture(reward: 100)
        fixture.state.fee = 1
        fixture.state.didReceiveAccountInfo(
            result: .success(AccountInfo(ethBalance: BigUInt(2_000_000))),
            chainAsset: fixture.feeAsset
        )
        XCTAssertTrue(try balanceCondition(fixture.state))
        fixture.state.didReceiveAccountInfo(result: .failure(CommonError.undefined), chainAsset: fixture.feeAsset)
        XCTAssertFalse(try balanceCondition(fixture.state))
    }

    private func rewardCondition(_ state: StakingPayoutConfirmationRelaychainViewModelState) throws -> Bool {
        try XCTUnwrap(state.validators(using: Locale(identifier: "en_US"))[1] as? WarningConditionViolation)
            .preservesCondition()
    }

    private func balanceCondition(_ state: StakingPayoutConfirmationRelaychainViewModelState) throws -> Bool {
        try XCTUnwrap(state.validators(using: Locale(identifier: "en_US"))[2] as? ErrorConditionViolation)
            .preservesCondition()
    }

    private struct Fixture {
        let state: StakingPayoutConfirmationRelaychainViewModelState
        let wallet: fearless.MetaAccountModel
        let rewardAsset: ChainAsset
        let feeAsset: ChainAsset

        func cachePrice(asset: AssetModel, price: String, currency: String? = nil) {
            ExactAssetPriceCache.shared.upsert([PriceData(
                currencyId: currency ?? wallet.selectedCurrency.id,
                priceId: asset.priceId!, price: price, fiatDayChange: nil, coingeckoPriceId: nil
            )])
        }
    }

    private func makeFixture(reward: Decimal, utilityReward: Bool = false) throws -> Fixture {
        let id = UUID().uuidString
        let fee = AssetModel(id: "fee", name: "Fee", symbol: "FEE", precision: 6,
                             isUtility: true, isNative: true, coingeckoPriceId: "fee-\(id)")
        let rewardToken = AssetModel(id: "reward", name: "Reward", symbol: "RWD", precision: 12,
                                     isUtility: false, isNative: false, coingeckoPriceId: "reward-\(id)")
        var chain = ChainModelGenerator.generateChain(generatingAssets: 0, addressPrefix: 42)
        chain.assets = [fee, rewardToken]
        let wallet = AccountGenerator.generateMetaAccount()
        let rewardAsset = ChainAsset(chain: chain, asset: utilityReward ? fee : rewardToken)
        let state = StakingPayoutConfirmationRelaychainViewModelState(
            chainAsset: rewardAsset, wallet: wallet, logger: nil,
            dataValidatingFactory: StakingDataValidatingFactory(presentable: StakingPayoutConfirmationWireframe()),
            callFactory: SubstrateCallFactoryDefault(runtimeService: PayoutRuntimeProvider())
        )
        state.didRecieve(account: try XCTUnwrap(wallet.fetch(for: chain.accountRequest())), rewardAmount: reward)
        return Fixture(state: state, wallet: wallet, rewardAsset: rewardAsset,
                       feeAsset: ChainAsset(chain: chain, asset: fee))
    }
}

private final class PayoutRuntimeProvider: RuntimeProviderProtocol {
    var runtimeSpecVersion: RuntimeSpecVersion = .defaultVersion
    var snapshot: RuntimeSnapshot?
    func setup() {}
    func setupHot() {}
    func cleanup() {}
    func readySnapshot() async throws -> RuntimeSnapshot {
        throw SSFRuntimeCodingService.RuntimeProviderError.providerUnavailable
    }
    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> { BaseOperation() }
    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        throw SSFRuntimeCodingService.RuntimeProviderError.providerUnavailable
    }
}
