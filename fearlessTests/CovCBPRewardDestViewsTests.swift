import XCTest
import SSFModels
import SSFUtils
import IrohaCrypto
import SoraFoundation
@testable import fearless

final class CovCBPRDVSetupPresenterDouble: StakingRewardDestSetupPresenterProtocol {
    var calls: [String] = []

    func setup() { calls.append("setup") }
    func selectRestakeDestination() { calls.append("restake") }
    func selectPayoutDestination() { calls.append("payout") }
    func selectPayoutAccount() { calls.append("account") }
    func displayLearnMore() { calls.append("learnMore") }
    func proceed() { calls.append("proceed") }
}

final class CovCBPRDVConfirmPresenterDouble: StakingRewardDestConfirmPresenterProtocol {
    var calls: [String] = []

    func setup() { calls.append("setup") }
    func confirm() { calls.append("confirm") }
    func presentSenderAccountOptions() { calls.append("sender") }
    func presentPayoutAccountOptions() { calls.append("payout") }
}

final class CovCBPRewardDestViewsTests: XCTestCase {
    private let languages = ["en"]
    private let locale = Locale(identifier: "en")

    private func makeManager() throws -> LocalizationManager {
        try XCTUnwrap(LocalizationManager(localization: "en"))
    }

    private func makeAddress(byte: UInt8) throws -> String {
        try SS58AddressFactory().address(fromAccountId: Data(repeating: byte, count: 32), type: 0)
    }

    private func makeIcon() throws -> DrawableIcon {
        try UniversalIconGenerator().generateFromAddress(try makeAddress(byte: 5))
    }

    private func makeReward(restakeAvailable: Bool) -> DestinationReturnViewModel {
        DestinationReturnViewModel(
            restakeAmount: "10 DOT",
            restakePercentage: "15%",
            restakePrice: "$50",
            payoutAmount: "9 DOT",
            payoutPercentage: "14%",
            payoutPrice: "$45",
            restakeAvailable: restakeAvailable
        )
    }

    private func makeSelection(
        type: RewardDestinationTypeViewModel,
        reward: DestinationReturnViewModel?,
        canApply: Bool
    ) -> ChangeRewardDestinationViewModel {
        let selection = LocalizableResource<RewardDestinationViewModelProtocol> { _ in
            RewardDestinationViewModel(rewardViewModel: reward, type: type)
        }
        return ChangeRewardDestinationViewModel(selectionViewModel: selection, canApply: canApply)
    }

    // MARK: - StakingRewardDestSetupLayout

    func testSetupLayoutLocalizes() {
        let layout = StakingRewardDestSetupLayout()
        layout.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        layout.locale = locale
        layout.layoutIfNeeded()

        XCTAssertTrue(layout.restakeOptionView.isHidden)
        XCTAssertEqual(layout.restakeOptionView.title, R.string.localizable.stakingRestakeTitle(preferredLanguages: languages))
        XCTAssertEqual(layout.payoutOptionView.title, R.string.localizable.commonPayout(preferredLanguages: languages))
        XCTAssertEqual(layout.accountView.title, R.string.localizable.stakingRewardPayoutAccount(preferredLanguages: languages))
        XCTAssertEqual(layout.learnMoreView.titleLabel.text, R.string.localizable.stakingRewardsLearnMore(preferredLanguages: languages))
        XCTAssertEqual(layout.actionButton.imageWithTitleView?.title, R.string.localizable.commonContinue(preferredLanguages: languages))
    }

    // MARK: - StakingRewardDestSetupViewController

    func testSetupControllerLoadsAndForwardsActions() throws {
        let presenter = CovCBPRDVSetupPresenterDouble()
        let controller = StakingRewardDestSetupViewController(presenter: presenter, localizationManager: try makeManager())
        controller.loadViewIfNeeded()
        controller.viewWillLayoutSubviews()

        XCTAssertEqual(presenter.calls, ["setup"])
        XCTAssertEqual(controller.title, R.string.localizable.stakingRewardsDestinationTitle(preferredLanguages: languages))
        XCTAssertTrue(controller.rootView.restakeOptionView.isSelected)
        XCTAssertFalse(controller.rootView.payoutOptionView.isSelected)

        controller.rootView.restakeOptionView.sendActions(for: .touchUpInside)
        controller.rootView.payoutOptionView.sendActions(for: .touchUpInside)
        controller.rootView.accountView.sendActions(for: .touchUpInside)
        controller.rootView.learnMoreView.sendActions(for: .touchUpInside)
        controller.rootView.actionButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(presenter.calls, ["setup", "payout", "account", "learnMore", "proceed"])
        XCTAssertEqual(controller.selectedLocale.identifier, "en")
    }

    func testSetupControllerAppliesRestakeSelection() throws {
        let presenter = CovCBPRDVSetupPresenterDouble()
        let controller = StakingRewardDestSetupViewController(presenter: presenter, localizationManager: try makeManager())
        controller.loadViewIfNeeded()

        controller.didReceiveRewardDestination(viewModel: makeSelection(type: .restake, reward: makeReward(restakeAvailable: true), canApply: true))

        let root = controller.rootView
        XCTAssertTrue(root.restakeOptionView.isSelected)
        XCTAssertFalse(root.payoutOptionView.isSelected)
        XCTAssertTrue(root.accountView.isHidden)
        XCTAssertFalse(root.restakeOptionView.isHidden)
        XCTAssertEqual(root.restakeOptionView.amountTitle, "10 DOT")
        XCTAssertEqual(root.restakeOptionView.priceTitle, "$50")
        XCTAssertEqual(root.restakeOptionView.incomeTitle, "15%")
        XCTAssertEqual(root.payoutOptionView.amountTitle, "9 DOT")
        XCTAssertEqual(root.payoutOptionView.priceTitle, "$45")
        XCTAssertEqual(root.payoutOptionView.incomeTitle, "14%")
        XCTAssertTrue(root.actionButton.isEnabled)

        root.restakeOptionView.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.calls, ["setup"])
    }

    func testSetupControllerAppliesPayoutSelectionAndFee() throws {
        let presenter = CovCBPRDVSetupPresenterDouble()
        let controller = StakingRewardDestSetupViewController(presenter: presenter, localizationManager: try makeManager())
        controller.loadViewIfNeeded()

        let type = RewardDestinationTypeViewModel.payout(icon: try makeIcon(), title: "Stash wallet", address: try makeAddress(byte: 5))
        controller.didReceiveRewardDestination(viewModel: makeSelection(type: type, reward: makeReward(restakeAvailable: false), canApply: false))

        let root = controller.rootView
        XCTAssertFalse(root.restakeOptionView.isSelected)
        XCTAssertTrue(root.payoutOptionView.isSelected)
        XCTAssertFalse(root.accountView.isHidden)
        XCTAssertTrue(root.restakeOptionView.isHidden)
        XCTAssertEqual(root.accountView.subtitle, "Stash wallet")
        XCTAssertNotNil(root.accountView.iconImage)
        XCTAssertFalse(root.actionButton.isEnabled)

        root.payoutOptionView.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.calls, ["setup"])

        controller.didReceiveRewardDestination(viewModel: makeSelection(type: .restake, reward: nil, canApply: true))
        XCTAssertTrue(root.restakeOptionView.isSelected)
        XCTAssertEqual(root.restakeOptionView.amountTitle, "10 DOT")

        controller.didReceiveRewardDestination(viewModel: nil)
        XCTAssertFalse(root.actionButton.isEnabled)

        controller.didReceiveFee(viewModel: LocalizableResource { _ in BalanceViewModel(amount: "0.7 DOT", price: "$3") })
        XCTAssertEqual(root.networkFeeView.tokenLabel.text, "0.7 DOT")
        XCTAssertEqual(root.networkFeeView.fiatLabel?.text, "$3")

        controller.didReceiveFee(viewModel: nil)
        XCTAssertNil(root.networkFeeView.tokenLabel.text)

        controller.applyLocalization()
        XCTAssertEqual(root.locale.identifier, "en")
    }

    // MARK: - StakingRewardDestConfirmViewLayout

    func testConfirmLayoutBindsRestakeAndPayout() throws {
        let layout = StakingRewardDestConfirmViewLayout()
        layout.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        layout.locale = locale
        layout.layoutIfNeeded()

        XCTAssertEqual(layout.senderAccountView.title, R.string.localizable.commonAccount(preferredLanguages: languages))
        XCTAssertEqual(layout.typeView.titleLabel.text, R.string.localizable.stakingRewardsDestinationTitle(preferredLanguages: languages))
        XCTAssertNil(layout.payoutAccountView)

        let icon = try makeIcon()
        layout.bind(confirmationViewModel: StakingRewardDestConfirmViewModel(senderIcon: icon, senderName: "Controller", rewardDestination: .restake))
        XCTAssertEqual(layout.senderAccountView.subtitle, "Controller")
        XCTAssertNotNil(layout.senderAccountView.iconImage)
        XCTAssertEqual(layout.typeView.valueLabel.text, R.string.localizable.stakingRestakeTitle(preferredLanguages: languages))
        XCTAssertNil(layout.payoutAccountView)

        let payout = RewardDestinationTypeViewModel.payout(icon: icon, title: "Payout wallet", address: try makeAddress(byte: 6))
        layout.bind(confirmationViewModel: StakingRewardDestConfirmViewModel(senderIcon: icon, senderName: "Controller", rewardDestination: payout))
        XCTAssertEqual(layout.typeView.valueLabel.text, R.string.localizable.commonPayout(preferredLanguages: languages))
        let payoutView = try XCTUnwrap(layout.payoutAccountView)
        XCTAssertEqual(payoutView.subtitle, "Payout wallet")
        XCTAssertEqual(payoutView.title, R.string.localizable.stakingRewardPayoutAccount(preferredLanguages: languages))

        layout.bind(confirmationViewModel: StakingRewardDestConfirmViewModel(senderIcon: icon, senderName: "Other", rewardDestination: payout))
        XCTAssertTrue(layout.payoutAccountView === payoutView)

        layout.locale = Locale(identifier: "ja")
        XCTAssertEqual(payoutView.title, R.string.localizable.stakingRewardPayoutAccount(preferredLanguages: ["ja"]))

        layout.bind(feeViewModel: BalanceViewModel(amount: "0.9 DOT", price: nil))
        XCTAssertEqual(layout.networkFeeFooterView.networkFeeView?.tokenLabel.text, "0.9 DOT")
    }

    // MARK: - StakingRewardDestConfirmViewController

    func testConfirmControllerLoadsAndForwardsActions() throws {
        let presenter = CovCBPRDVConfirmPresenterDouble()
        let controller = StakingRewardDestConfirmViewController(presenter: presenter, localizationManager: try makeManager())
        controller.loadViewIfNeeded()

        XCTAssertEqual(presenter.calls, ["setup"])
        XCTAssertEqual(controller.title, R.string.localizable.commonConfirmTitle(preferredLanguages: languages))
        XCTAssertEqual(controller.selectedLocale.identifier, "en")

        controller.rootView.senderAccountView.sendActions(for: .touchUpInside)
        controller.rootView.networkFeeFooterView.actionButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.calls, ["setup", "sender", "confirm"])

        controller.didReceiveFee(viewModel: nil)
        XCTAssertNil(controller.rootView.networkFeeFooterView.networkFeeView)

        controller.didReceiveFee(viewModel: LocalizableResource { _ in BalanceViewModel(amount: "1.1 DOT", price: nil) })
        XCTAssertEqual(controller.rootView.networkFeeFooterView.networkFeeView?.tokenLabel.text, "1.1 DOT")
    }

    func testConfirmControllerAddsPayoutAccountTargetOnce() throws {
        let presenter = CovCBPRDVConfirmPresenterDouble()
        let controller = StakingRewardDestConfirmViewController(presenter: presenter, localizationManager: try makeManager())
        controller.loadViewIfNeeded()

        let icon = try makeIcon()
        let payout = RewardDestinationTypeViewModel.payout(icon: icon, title: "Payout", address: try makeAddress(byte: 8))
        let viewModel = StakingRewardDestConfirmViewModel(senderIcon: icon, senderName: "Ctrl", rewardDestination: payout)

        controller.didReceiveConfirmation(viewModel: viewModel)
        controller.didReceiveConfirmation(viewModel: viewModel)
        controller.applyLocalization()

        let payoutView = try XCTUnwrap(controller.rootView.payoutAccountView)
        payoutView.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.calls, ["setup", "payout"])
        XCTAssertEqual(controller.rootView.senderAccountView.subtitle, "Ctrl")
    }

    func testConfirmControllerSealWithoutLoader() throws {
        let controller = StakingRewardDestConfirmViewController(
            presenter: CovCBPRDVConfirmPresenterDouble(),
            localizationManager: try makeManager()
        )
        controller.loadViewIfNeeded()

        controller.didReachTransferStage(.ready)
        controller.didBreakTransfer()
        XCTAssertNil(FWTransferSeal.sealView(in: controller.view))
    }

    // MARK: - StakingRewardDestConfirmVMFactory

    func testConfirmViewModelFactoryRestakeAndPayout() throws {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let wallet = AccountGenerator.generateMetaAccount()
        let account = try XCTUnwrap(wallet.fetch(for: chain.accountRequest()))
        let stash = StashItem(stash: try makeAddress(byte: 1), controller: try makeAddress(byte: 2))
        let factory = StakingRewardDestConfirmVMFactory(iconGenerator: UniversalIconGenerator())

        let restake = try factory.createViewModel(from: stash, rewardDestination: .restake, controller: nil)
        XCTAssertEqual(restake.senderName, stash.controller)
        guard case .restake = restake.rewardDestination else { return XCTFail("restake expected") }

        let payout = try factory.createViewModel(from: stash, rewardDestination: .payout(account: account), controller: account)
        XCTAssertEqual(payout.senderName, wallet.name)
        guard case let .payout(_, title, address) = payout.rewardDestination else { return XCTFail("payout expected") }
        XCTAssertEqual(title, wallet.name)
        XCTAssertEqual(address, try account.toDisplayAddress().address)

        let broken = StashItem(stash: "x", controller: "not-an-address")
        XCTAssertThrowsError(try factory.createViewModel(from: broken, rewardDestination: .restake, controller: nil))
    }
}
