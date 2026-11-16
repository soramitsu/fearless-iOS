import XCTest
import SSFModels
import SoraFoundation
@testable import fearless

struct CovCABBVMDefaultFactory: StakingAmountViewModelFactoryProtocol {}

struct CovCABBVMDefaultInputHandler: StakingAmountUserInputHandler {}

final class CovCABBVMState: StakingAmountViewModelState {
    var stateListener: StakingAmountModelStateListener?
    var feeExtrinsicBuilderClosure: ExtrinsicBuilderClosure { { $0 } }
    var amount: Decimal? { 1 }
    var fee: Decimal?
    var bonding: InitiatedBonding? { nil }
    var payoutAccount: fearless.ChainAccountResponse? { nil }
    var learnMoreUrl: URL? { nil }
    var continueAvailable: Bool { true }
    var rewardChainAsset: ChainAsset? { nil }

    func setStateListener(_ stateListener: StakingAmountModelStateListener?) {
        self.stateListener = stateListener
    }

    func validators(using _: Locale) -> [DataValidating] { [] }
    func updateBalance(_: Decimal?) {}
}

final class CovCABBalanceViewModelFactoryTests: XCTestCase {
    private let locale = Locale(identifier: "en")
    private var wallet: fearless.MetaAccountModel!
    private var asset: AssetModel!
    private var factory: BalanceViewModelFactory!
    private let price = PriceData(currencyId: "usd", priceId: "dot", price: "2", fiatDayChange: nil, coingeckoPriceId: nil)

    override func setUp() {
        super.setUp()
        wallet = AccountGenerator.generateMetaAccount()
        asset = AssetModel(
            id: "dot",
            name: "DOT",
            symbol: "DOT",
            precision: 10,
            icon: Constants.dummyURL,
            currencyId: nil,
            existentialDeposit: nil,
            color: nil,
            isUtility: true,
            isNative: true,
            staking: nil,
            purchaseProviders: nil,
            type: nil,
            ethereumType: nil,
            priceProvider: nil,
            coingeckoPriceId: nil
        )
        factory = BalanceViewModelFactory(targetAssetInfo: asset.displayInfo, selectedMetaAccount: wallet)
    }

    override func tearDown() {
        factory = nil
        asset = nil
        wallet = nil
        super.tearDown()
    }

    func testAssetBalanceWithPriceAppendsFiat() {
        let viewModel = factory.createAssetBalanceViewModel(3, balance: 10, priceData: price, selectable: false).value(for: locale)

        XCTAssertEqual(viewModel.symbol, asset.displayInfo.symbol)
        XCTAssertFalse(viewModel.selectable)
        XCTAssertNotNil(viewModel.iconViewModel)
        let fiat = viewModel.fiatBalance
        XCTAssertNotNil(fiat)
        XCTAssertTrue(viewModel.balance?.contains("(\(fiat ?? "-"))") == true)
        XCTAssertEqual(viewModel.price, factory.priceFromAmount(3, priceData: price).value(for: locale))
    }

    func testAssetBalanceClampsNegativeAndHandlesMissingData() {
        let negative = factory.createAssetBalanceViewModel(nil, balance: -5, priceData: nil).value(for: locale)
        let zero = factory.createAssetBalanceViewModel(nil, balance: 0, priceData: nil).value(for: locale)
        XCTAssertEqual(negative.balance, zero.balance)
        XCTAssertNil(negative.price)
        XCTAssertNil(negative.fiatBalance)
        XCTAssertTrue(negative.selectable)

        let empty = factory.createAssetBalanceViewModel(1, balance: nil, priceData: price).value(for: locale)
        XCTAssertNil(empty.balance)
        XCTAssertNotNil(empty.price)

        let badPrice = PriceData(currencyId: "usd", priceId: "dot", price: "abc", fiatDayChange: nil, coingeckoPriceId: nil)
        let unpriced = factory.createAssetBalanceViewModel(1, balance: 2, priceData: badPrice).value(for: locale)
        XCTAssertNil(unpriced.price)
        XCTAssertNil(unpriced.fiatBalance)
    }

    func testBalanceFromPriceVariants() throws {
        let plain = factory.balanceFromPrice(5, priceData: nil, usageCase: .detailsCrypto).value(for: locale)
        XCTAssertNil(plain.price)
        XCTAssertFalse(plain.amount.isEmpty)

        let priced = factory.balanceFromPrice(5, priceData: price, usageCase: .detailsCrypto).value(for: locale)
        let approximate = factory.balanceFromPrice(5, priceData: price, isApproximately: true, usageCase: .detailsCrypto)
            .value(for: locale)
        let pricedValue = try XCTUnwrap(priced.price)
        XCTAssertEqual(approximate.price, "~" + pricedValue)
        XCTAssertEqual(approximate.amount, priced.amount)
    }

    func testPriceAndAmountFormatting() {
        let badPrice = PriceData(currencyId: "usd", priceId: "dot", price: "n/a", fiatDayChange: nil, coingeckoPriceId: nil)
        XCTAssertEqual(factory.priceFromAmount(1, priceData: badPrice).value(for: locale), "")
        XCTAssertTrue(factory.priceFromAmount(1, priceData: price).value(for: locale).contains("2"))
        XCTAssertFalse(factory.amountFromValue(1.5, usageCase: .listCrypto).value(for: locale).isEmpty)
        XCTAssertFalse(factory.plainAmountFromValue(1.5, usageCase: .listCrypto).value(for: locale).isEmpty)

        let input = factory.createBalanceInputViewModel(2).value(for: locale)
        XCTAssertTrue(input.isValid)
        XCTAssertEqual(input.decimalAmount, 2)
    }

    func testMetaAccountChangeSwitchesCurrency() {
        let usdPrice = factory.priceFromAmount(1, priceData: price).value(for: locale)
        XCTAssertTrue(usdPrice.contains("$"))

        let otherWallet = AccountGenerator.generateMetaAccount().replacingCurrency(Currency.euro())
        factory.processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: otherWallet))
        XCTAssertEqual(factory.priceFromAmount(1, priceData: price).value(for: locale), usdPrice)

        factory.processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: wallet.replacingCurrency(Currency.euro())))
        XCTAssertTrue(factory.priceFromAmount(1, priceData: price).value(for: locale).contains("€"))
    }

    func testStakingAmountProtocolDefaults() throws {
        let defaultFactory = CovCABBVMDefaultFactory()
        let state = CovCABBVMState()

        XCTAssertNil(defaultFactory.buildViewModel(viewModelState: state, priceData: nil, calculator: nil))
        XCTAssertNil(try defaultFactory.buildSelectRewardDestinationViewModel(viewModelState: state, priceData: nil, calculator: nil))

        let handler = CovCABBVMDefaultInputHandler()
        handler.selectRestakeDestination()
        handler.selectPayoutDestination()
        handler.selectAmountPercentage(0.5)
        handler.selectPayoutAccount(payoutAccount: nil)
        handler.updateAmount(1)

        state.selectRestakeDestination()
        state.updateAmount(3)
        XCTAssertEqual(state.amount, 1)
        XCTAssertNil(state.stateListener)
        XCTAssertEqual(StakingAmountFlow.relaychain, .relaychain)
    }
}
