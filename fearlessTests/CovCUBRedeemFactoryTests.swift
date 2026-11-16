import XCTest
import BigInt
import SSFModels
@testable import fearless

final class CovCUBRedeemFactoryTests: XCTestCase {
    private var chainAsset: ChainAsset!
    private var wallet: fearless.MetaAccountModel!
    private var validatingFactory: StakingDataValidatingFactory!
    private var icons: CovCUBIconGenerator!
    private let en = ["en"]

    override func setUp() {
        super.setUp()
        chainAsset = CovCUBFixture.chainAsset(color: "#AABBCC")
        wallet = CovCUBFixture.wallet()
        validatingFactory = StakingDataValidatingFactory(presentable: CovCUBStakingErrorSpy())
        icons = CovCUBIconGenerator()
    }

    override func tearDown() {
        chainAsset = nil
        wallet = nil
        validatingFactory = nil
        icons = nil
        super.tearDown()
    }

    private var balanceFactory: BalanceViewModelFactory {
        CovCUBFixture.balanceFactory(wallet: wallet)
    }

    private func inputString(_ value: Decimal) -> String {
        AssetBalanceFormatterFactory()
            .createInputFormatter(for: chainAsset.asset.displayInfo)
            .value(for: CovCUBFixture.english)
            .string(from: value as NSNumber) ?? ""
    }

    private func tokenString(_ value: Decimal) -> String {
        AssetBalanceFormatterFactory()
            .createTokenFormatter(for: chainAsset.asset.displayInfo, usageCase: .detailsCrypto)
            .value(for: CovCUBFixture.english)
            .stringFromDecimal(value) ?? ""
    }

    private func redeemRelay() -> StakingRedeemRelaychainViewModelState {
        StakingRedeemRelaychainViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            callFactory: CovCUBCallFactoryStub()
        )
    }

    private func redeemPool() -> StakingRedeemPoolViewModelState {
        StakingRedeemPoolViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            callFactory: CovCUBCallFactoryStub()
        )
    }

    private func confirmRelay() -> StakingRedeemConfirmationRelaychainViewModelState {
        StakingRedeemConfirmationRelaychainViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            callFactory: CovCUBCallFactoryStub()
        )
    }

    private func confirmPool() -> StakingRedeemConfirmationPoolViewModelState {
        StakingRedeemConfirmationPoolViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            callFactory: CovCUBCallFactoryStub()
        )
    }

    // MARK: - Redeem relaychain

    func testRedeemRelaychainFactoryNeedsEraAndLedger() throws {
        let factory = StakingRedeemRelaychainViewModelFactory(
            asset: chainAsset.asset,
            balanceViewModelFactory: balanceFactory,
            iconGenerator: icons
        )
        let state = redeemRelay()

        XCTAssertNil(factory.buildViewModel(viewModelState: state))
        XCTAssertNil(factory.buildAssetViewModel(viewModelState: state, priceData: nil))
        XCTAssertNil(factory.buildViewModel(viewModelState: redeemPool()))
        XCTAssertNil(factory.buildAssetViewModel(viewModelState: redeemPool(), priceData: nil))

        state.didReceiveActiveEra(result: .success(CovCUBFixture.activeEra(4)))
        XCTAssertNil(factory.buildViewModel(viewModelState: state))
        XCTAssertTrue(factory.buildHints().value(for: CovCUBFixture.english).isEmpty)
    }

    func testRedeemRelaychainFactoryBuildsRedeemableAmount() throws {
        let factory = StakingRedeemRelaychainViewModelFactory(
            asset: chainAsset.asset,
            balanceViewModelFactory: balanceFactory,
            iconGenerator: icons
        )
        let state = redeemRelay()
        state.didReceiveStakingLedger(result: .success(try CovCUBFixture.ledger(active: 1, unlocking: [(2, 3), (5, 9)])))
        state.didReceiveActiveEra(result: .success(CovCUBFixture.activeEra(4)))

        let anonymous = try XCTUnwrap(factory.buildViewModel(viewModelState: state))
        XCTAssertEqual(anonymous.senderAddress, "")
        XCTAssertNil(anonymous.senderName)
        XCTAssertNil(anonymous.senderIcon)
        XCTAssertEqual(anonymous.amount.value(for: CovCUBFixture.english), inputString(2))
        XCTAssertEqual(
            anonymous.title.value(for: CovCUBFixture.english),
            R.string.localizable.commonConfirmTitle(preferredLanguages: en)
        )

        state.didReceiveController(result: .success(try CovCUBFixture.account(for: chainAsset, wallet: wallet)))
        let named = try XCTUnwrap(factory.buildViewModel(viewModelState: state))
        XCTAssertEqual(named.senderAddress, try CovCUBFixture.address(for: chainAsset, wallet: wallet))
        XCTAssertEqual(named.senderName, wallet.name)
        XCTAssertNotNil(named.senderIcon)

        let asset = try XCTUnwrap(factory.buildAssetViewModel(viewModelState: state, priceData: nil))
            .value(for: CovCUBFixture.english)
        XCTAssertEqual(asset.symbol.uppercased(), "DOT")
        XCTAssertNotNil(asset.balance)
    }

    // MARK: - Redeem pool

    func testRedeemPoolFactoryBuildsRedeemableAmountAndHint() throws {
        let factory = StakingRedeemPoolViewModelFactory(
            asset: chainAsset.asset,
            balanceViewModelFactory: balanceFactory,
            iconGenerator: icons
        )
        let state = redeemPool()

        XCTAssertNil(factory.buildViewModel(viewModelState: state))
        XCTAssertNil(factory.buildAssetViewModel(viewModelState: state, priceData: nil))
        XCTAssertNil(factory.buildViewModel(viewModelState: redeemRelay()))
        XCTAssertNil(factory.buildAssetViewModel(viewModelState: redeemRelay(), priceData: nil))

        state.didReceiveStakeInfo(result: .success(try CovCUBFixture.poolMember(points: 1, unbonding: [(1.5, 3), (4, 8)])))
        state.didReceiveActiveEra(result: .success(CovCUBFixture.activeEra(3)))

        let viewModel = try XCTUnwrap(factory.buildViewModel(viewModelState: state))
        XCTAssertEqual(viewModel.senderAddress, try CovCUBFixture.address(for: chainAsset, wallet: wallet))
        XCTAssertEqual(viewModel.senderName, wallet.name)
        XCTAssertNotNil(viewModel.senderIcon)
        XCTAssertEqual(viewModel.amount.value(for: CovCUBFixture.english), inputString(1.5))
        XCTAssertEqual(
            viewModel.title.value(for: CovCUBFixture.english),
            R.string.localizable.stakingRevokeTokens(preferredLanguages: en)
        )
        XCTAssertNotNil(factory.buildAssetViewModel(viewModelState: state, priceData: nil))

        let hints = factory.buildHints().value(for: CovCUBFixture.english)
        XCTAssertEqual(hints.map(\.title), [R.string.localizable.stakingStakeLessHint(preferredLanguages: en)])
        XCTAssertNotNil(hints.first?.icon)
    }

    // MARK: - Redeem confirmation relaychain

    func testRedeemConfirmationRelaychainFactory() throws {
        let factory = StakingRedeemConfirmationRelaychainViewModelFactory(
            asset: chainAsset.asset,
            balanceViewModelFactory: balanceFactory,
            iconGenerator: icons
        )
        let state = confirmRelay()

        XCTAssertNil(factory.buildViewModel(viewModelState: state))
        XCTAssertNil(factory.buildAssetViewModel(viewModelState: state, priceData: nil))
        XCTAssertNil(factory.buildViewModel(viewModelState: confirmPool()))
        XCTAssertNil(factory.buildAssetViewModel(viewModelState: confirmPool(), priceData: nil))
        XCTAssertTrue(factory.buildHints().value(for: CovCUBFixture.english).isEmpty)

        state.didReceiveStakingLedger(result: .success(try CovCUBFixture.ledger(active: 1, unlocking: [(3, 2)])))
        state.didReceiveActiveEra(result: .success(CovCUBFixture.activeEra(2)))
        state.didReceiveController(result: .success(try CovCUBFixture.account(for: chainAsset, wallet: wallet)))

        let viewModel = try XCTUnwrap(factory.buildViewModel(viewModelState: state))
        XCTAssertEqual(viewModel.senderAddress, try CovCUBFixture.address(for: chainAsset, wallet: wallet))
        XCTAssertEqual(viewModel.senderName, wallet.name)
        XCTAssertEqual(viewModel.amountString.value(for: CovCUBFixture.english), inputString(3))
        XCTAssertEqual(
            viewModel.title.value(for: CovCUBFixture.english),
            R.string.localizable.commonConfirmTitle(preferredLanguages: en)
        )
        let staked = try XCTUnwrap(viewModel.stakeAmountViewModel?.value(for: CovCUBFixture.english))
        XCTAssertEqual(
            staked.amountTitle.string,
            R.string.localizable.poolStakingUnstakeAmountTitle(tokenString(3), preferredLanguages: en)
        )
        XCTAssertEqual(staked.color, "#AABBCC")
        XCTAssertNotNil(factory.buildAssetViewModel(viewModelState: state, priceData: nil))
    }

    // MARK: - Redeem confirmation pool

    func testRedeemConfirmationPoolFactory() throws {
        let factory = StakingRedeemConfirmationPoolViewModelFactory(
            asset: chainAsset.asset,
            balanceViewModelFactory: balanceFactory,
            iconGenerator: icons
        )
        let state = confirmPool()

        XCTAssertNil(factory.buildViewModel(viewModelState: state))
        XCTAssertNil(factory.buildAssetViewModel(viewModelState: state, priceData: nil))
        XCTAssertNil(factory.buildViewModel(viewModelState: confirmRelay()))
        XCTAssertNil(factory.buildAssetViewModel(viewModelState: confirmRelay(), priceData: nil))
        XCTAssertTrue(factory.buildHints().value(for: CovCUBFixture.english).isEmpty)

        state.didReceiveStakeInfo(result: .success(try CovCUBFixture.poolMember(points: 2, unbonding: [(0.5, 1)])))
        state.didReceiveActiveEra(result: .success(CovCUBFixture.activeEra(1)))

        let viewModel = try XCTUnwrap(factory.buildViewModel(viewModelState: state))
        XCTAssertEqual(viewModel.senderAddress, try CovCUBFixture.address(for: chainAsset, wallet: wallet))
        XCTAssertEqual(viewModel.senderName, wallet.name)
        XCTAssertEqual(viewModel.amountString.value(for: CovCUBFixture.english), inputString(0.5))
        XCTAssertEqual(
            viewModel.title.value(for: CovCUBFixture.english),
            R.string.localizable.stakingRedeem(preferredLanguages: en)
        )
        let staked = try XCTUnwrap(factory.createStakedAmountViewModel(0.5)?.value(for: CovCUBFixture.english))
        XCTAssertEqual(
            staked.amountTitle.string,
            R.string.localizable.poolStakingUnstakeAmountTitle(tokenString(0.5), preferredLanguages: en)
        )

        let asset = try XCTUnwrap(factory.buildAssetViewModel(viewModelState: state, priceData: nil))
            .value(for: CovCUBFixture.english)
        XCTAssertNotNil(asset.balance)
    }
}
