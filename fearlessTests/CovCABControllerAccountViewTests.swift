import XCTest
import SSFModels
import SoraFoundation
import SSFUtils
@testable import fearless

final class CovCABCAVPresenter: ControllerAccountPresenterProtocol {
    private(set) var loadedViews: [ControllerAccountViewProtocol] = []
    private(set) var stashActions = 0
    private(set) var controllerActions = 0
    private(set) var learnMoreCalls = 0
    private(set) var proceedCalls = 0

    func didLoad(view: ControllerAccountViewProtocol) { loadedViews.append(view) }
    func handleStashAction() { stashActions += 1 }
    func handleControllerAction() { controllerActions += 1 }
    func selectLearnMore() { learnMoreCalls += 1 }
    func proceed() { proceedCalls += 1 }
}

enum CovCABCAVFixtures {
    static func soraChain() -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: Data(repeating: 4, count: 32).toHex(),
            paraId: nil,
            name: "SORA Mainnet",
            xcm: nil,
            nodes: Set([ChainNodeModel(url: Constants.dummyURL, name: "node", apikey: nil)]),
            addressPrefix: 69,
            icon: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    static func viewModel(
        chain: ChainModel,
        isController: Bool,
        enabled: Bool
    ) -> ControllerAccountViewModel {
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        return ControllerAccountViewModel(
            chainAsset: ChainAsset(chain: chain, asset: asset),
            stashViewModel: LocalizableResource { _ in
                AccountInfoViewModel(title: "Stash", address: "stash-address", name: "Stash name", icon: R.image.iconWarning())
            },
            controllerViewModel: LocalizableResource { _ in
                AccountInfoViewModel(title: "Controller", address: "ctrl-address", name: "Controller name", icon: nil)
            },
            currentAccountIsController: isController,
            actionButtonIsEnabled: enabled
        )
    }
}

final class CovCABControllerAccountViewTests: XCTestCase {
    private let locale = Locale(identifier: "en")
    private let languages = ["en"]

    func testLayoutLocalizesTextsWhenLocaleChanges() {
        let layout = ControllerAccountViewLayout()
        layout.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        layout.locale = Locale(identifier: "ru")
        layout.locale = locale
        layout.layoutIfNeeded()

        XCTAssertEqual(layout.stashHintView.titleLabel.text, R.string.localizable.stakingStashCanHint(preferredLanguages: languages))
        XCTAssertEqual(
            layout.controllerHintView.titleLabel.text,
            R.string.localizable.stakingControllerCanHint(preferredLanguages: languages)
        )
        XCTAssertEqual(layout.learnMoreView.titleLabel.text, R.string.localizable.commonLearnMore(preferredLanguages: languages))
        XCTAssertEqual(
            layout.currentAccountIsControllerHint.titleLabel.text,
            R.string.localizable.stakingSwitchAccountToStash(preferredLanguages: languages)
        )
        XCTAssertEqual(layout.actionButton.imageWithTitleView?.title, R.string.localizable.commonContinue(preferredLanguages: languages))
        XCTAssertEqual(layout.feeView.titleLabel.text, R.string.localizable.commonNetworkFee(preferredLanguages: languages))
        XCTAssertNotNil(layout.currentAccountIsControllerHint.iconView.image)
    }

    func testLayoutBindDescriptionDependsOnChain() {
        let layout = ControllerAccountViewLayout()
        layout.locale = locale

        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        layout.bind(viewModel: CovCABCAVFixtures.viewModel(chain: chain, isController: false, enabled: true))
        XCTAssertEqual(
            layout.descriptionLabel.text,
            R.string.localizable.stakingControllerDeprecatedDescription(chain.name, preferredLanguages: languages)
        )

        layout.bind(viewModel: CovCABCAVFixtures.viewModel(chain: CovCABCAVFixtures.soraChain(), isController: false, enabled: true))
        XCTAssertEqual(
            layout.descriptionLabel.text,
            R.string.localizable.stakingSetSeparateAccountController(preferredLanguages: languages)
        )
    }

    func testViewControllerLoadsAndReloads() throws {
        let presenter = CovCABCAVPresenter()
        let controller = ControllerAccountViewController(
            presenter: presenter,
            localizationManager: LocalizationManager(localization: "en")
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        defer { window.isHidden = true }

        XCTAssertEqual(presenter.loadedViews.count, 1)
        XCTAssertEqual(controller.title, R.string.localizable.stakingControllerAccountTitle(preferredLanguages: languages))
        XCTAssertEqual(controller.rootView.locale.identifier, "en")

        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        controller.reload(with: CovCABCAVFixtures.viewModel(chain: chain, isController: true, enabled: false))

        XCTAssertEqual(controller.rootView.stashAccountView.title, "Stash")
        XCTAssertEqual(controller.rootView.stashAccountView.subtitle, "Stash name")
        XCTAssertNotNil(controller.rootView.stashAccountView.iconImage)
        XCTAssertEqual(controller.rootView.controllerAccountView.title, "Controller")
        XCTAssertEqual(controller.rootView.controllerAccountView.subtitle, "Controller name")
        XCTAssertFalse(controller.rootView.actionButton.isEnabled)
        XCTAssertFalse(controller.rootView.currentAccountIsControllerHint.isHidden)
        XCTAssertNotNil(controller.rootView.controllerAccountView.actionImage)

        controller.reload(with: CovCABCAVFixtures.viewModel(chain: CovCABCAVFixtures.soraChain(), isController: false, enabled: true))
        XCTAssertTrue(controller.rootView.actionButton.isEnabled)
        XCTAssertTrue(controller.rootView.currentAccountIsControllerHint.isHidden)
        XCTAssertEqual(
            controller.rootView.descriptionLabel.text,
            R.string.localizable.stakingSetSeparateAccountController(preferredLanguages: languages)
        )

        controller.didReceive(feeViewModel: LocalizableResource { _ in BalanceViewModel(amount: "0.1 DOT", price: "$1") })
        XCTAssertEqual(controller.rootView.feeView.tokenLabel.text, "0.1 DOT")
        XCTAssertEqual(controller.rootView.feeView.fiatLabel?.text, "$1")

        controller.didReceive(chainName: "Polkadot")
        controller.applyLocalization()
        XCTAssertEqual(controller.selectedLocale.identifier, "en")
    }

    func testViewControllerControlsCallPresenter() {
        let presenter = CovCABCAVPresenter()
        let controller = ControllerAccountViewController(presenter: presenter, localizationManager: nil)
        controller.loadViewIfNeeded()

        controller.rootView.actionButton.sendActions(for: .touchUpInside)
        controller.rootView.learnMoreView.sendActions(for: .touchUpInside)
        controller.rootView.stashAccountView.sendActions(for: .touchUpInside)
        controller.rootView.controllerAccountView.sendActions(for: .touchUpInside)

        XCTAssertEqual(presenter.proceedCalls, 1)
        XCTAssertEqual(presenter.learnMoreCalls, 1)
        XCTAssertEqual(presenter.stashActions, 1)
        XCTAssertEqual(presenter.controllerActions, 1)
    }

    func testViewModelFactoryMarksCurrentController() throws {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        let current = try XCTUnwrap(AccountGenerator.generateMetaAccount().fetch(for: chain.accountRequest()))
        let stashAccount = try XCTUnwrap(AccountGenerator.generateMetaAccount().fetch(for: chain.accountRequest()))
        let currentAddress = try XCTUnwrap(current.toAddress())
        let stashAddress = try XCTUnwrap(stashAccount.toAddress())
        let factory = ControllerAccountViewModelFactory(currentAccountItem: current, iconGenerator: UniversalIconGenerator())

        let viewModel = factory.createViewModel(
            stashItem: StashItem(stash: stashAddress, controller: currentAddress),
            stashAccountItem: stashAccount,
            chosenAccountItem: nil,
            chainAsset: chainAsset
        )

        XCTAssertTrue(viewModel.currentAccountIsController)
        XCTAssertFalse(viewModel.actionButtonIsEnabled)
        XCTAssertFalse(viewModel.canChooseOtherController)

        let stash = viewModel.stashViewModel.value(for: locale)
        XCTAssertEqual(stash.title, R.string.localizable.stackingStashAccount(preferredLanguages: languages))
        XCTAssertEqual(stash.address, stashAddress)
        XCTAssertEqual(stash.name, stashAccount.name)
        XCTAssertNotNil(stash.icon)

        let controller = viewModel.controllerViewModel.value(for: locale)
        XCTAssertEqual(controller.title, R.string.localizable.stakingControllerAccountTitle(preferredLanguages: languages))
        XCTAssertEqual(controller.address, currentAddress)
        XCTAssertEqual(controller.name, currentAddress)
    }

    func testViewModelFactoryWithChosenAccountAndSameStash() throws {
        let chain = CovCABCAVFixtures.soraChain()
        let asset = ChainModelGenerator.generateAssetWithId("xor", symbol: "XOR", assetPresicion: 18)
        let current = try XCTUnwrap(AccountGenerator.generateMetaAccount().fetch(for: chain.accountRequest()))
        let chosen = try XCTUnwrap(AccountGenerator.generateMetaAccount().fetch(for: chain.accountRequest()))
        let currentAddress = try XCTUnwrap(current.toAddress())
        let factory = ControllerAccountViewModelFactory(currentAccountItem: current, iconGenerator: UniversalIconGenerator())

        let viewModel = factory.createViewModel(
            stashItem: StashItem(stash: currentAddress, controller: currentAddress),
            stashAccountItem: nil,
            chosenAccountItem: chosen,
            chainAsset: ChainAsset(chain: chain, asset: asset)
        )

        XCTAssertFalse(viewModel.currentAccountIsController)
        XCTAssertTrue(viewModel.actionButtonIsEnabled)
        XCTAssertTrue(viewModel.canChooseOtherController)
        XCTAssertEqual(viewModel.stashViewModel.value(for: locale).name, currentAddress)
        let controller = viewModel.controllerViewModel.value(for: locale)
        XCTAssertEqual(controller.address, chosen.toAddress())
        XCTAssertEqual(controller.name, chosen.name)
    }
}
