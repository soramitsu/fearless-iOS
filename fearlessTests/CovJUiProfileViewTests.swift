import XCTest
import UIKit
import SoraFoundation
import SoraKeystore
import SSFModels
import SSFUtils
@testable import fearless

final class CovJUiBiometry: BiometryAuthProtocol {
    let availableBiometryType: AvailableBiometryType

    init(_ type: AvailableBiometryType) {
        availableBiometryType = type
    }

    func authenticate(localizedReason _: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void) {
        completionQueue.async { completionBlock(false) }
    }
}

final class CovJUiProfilePresenterSpy: ProfilePresenterProtocol {
    private(set) weak var loadedView: ProfileViewProtocol?
    private(set) var detailsCalls = 0
    private(set) var options: [ProfileOption] = []
    private(set) var logouts = 0
    private(set) var switches: [String] = []

    func didLoad(view: ProfileViewProtocol) { loadedView = view }
    func activateAccountDetails() { detailsCalls += 1 }
    func activateOption(_ option: ProfileOption) { options.append(option) }
    func logout() { logouts += 1 }
    func switcherValueChanged(isOn: Bool, index: Int) { switches.append("\(isOn):\(index)") }
}

enum CovJUiProfileModels {
    static let locale = Locale(identifier: "en")

    /// A real factory whose sound and haptic switches live in a throwaway defaults suite.
    static func factory(
        _ biometry: AvailableBiometryType,
        settings: SettingsManagerProtocol,
        policy: IrohaConnectReleasePolicy = .production,
        sound: Bool = true,
        haptics: Bool = true,
        test: XCTestCase
    ) throws -> ProfileViewModelFactory {
        let suite = "CovJUiProfile.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        test.addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let feedback = FWFeedbackSettings(defaults: defaults, notificationCenter: NotificationCenter())
        feedback.soundEnabled = sound
        feedback.hapticsEnabled = haptics
        return ProfileViewModelFactory(
            iconGenerator: UniversalIconGenerator(),
            biometry: CovJUiBiometry(biometry),
            settings: settings,
            irohaConnectPolicy: policy,
            feedbackSettings: feedback
        )
    }

    static func switchState(_ viewModel: ProfileOptionViewModelProtocol?) -> Bool? {
        guard let viewModel, case let .switcher(isOn) = viewModel.accessoryType else {
            return nil
        }
        return isOn
    }

    static func tonAccount() -> SSFModels.ChainAccountModel {
        SSFModels.ChainAccountModel(
            chainId: UniversalWalletRegistry.tonMainnetRegistryEntry.chainId,
            accountId: Data(repeating: 7, count: 32),
            publicKey: Data(repeating: 8, count: 32),
            cryptoType: 0,
            ethereumBased: false
        )
    }
}

// MARK: - View model factory

final class CovJUiProfileViewModelFactoryTests: XCTestCase {
    private let locale = CovJUiProfileModels.locale
    private var languages: [String]? { locale.rLanguages }

    private func balance(percent: Decimal, value: Decimal, hiddenFiat: Decimal = 0) -> WalletBalanceInfo {
        var exclusions = PortfolioExclusions()
        exclusions.hiddenFiat = hiddenFiat
        return WalletBalanceInfo(
            totalFiatValue: 12.5, enabledAssetFiatBalance: 7.5,
            dayChangePercent: 0.01, dayChangeValue: 0.1,
            totalDayChangePercent: percent, totalDayChangeValue: value,
            currency: .defaultCurrency(), prices: [], accountInfos: [:], exclusions: exclusions, filteredPart: nil
        )
    }

    private func model(
        _ factory: ProfileViewModelFactory,
        wallet: MetaAccountModel = AccountGenerator.generateMetaAccount(),
        currency: Currency = .defaultCurrency(),
        balance: WalletBalanceInfo? = nil,
        issues: [ChainIssue] = []
    ) -> ProfileViewModelProtocol {
        factory.createProfileViewModel(
            from: wallet, locale: locale, language: Language(code: "en"), currency: currency, balance: balance, missingAccountIssue: issues
        )
    }

    func testUserViewModelFormatsBalanceDayChangeAndHiddenCaption() throws {
        let factory = try CovJUiProfileModels.factory(.none, settings: InMemorySettingsManager(), test: self)
        let wallet = AccountGenerator.generateMetaAccount()
        let info = balance(percent: 0.05, value: -2.5, hiddenFiat: 5)
        let user = model(factory, wallet: wallet, balance: info).profileUserViewModel

        XCTAssertEqual(user.walletName, wallet.name)
        XCTAssertFalse(user.isSelected)
        let fiat = try XCTUnwrap(user.fiatBalance)
        XCTAssertTrue(fiat.hasPrefix("$12"), fiat)

        let change = try XCTUnwrap(user.dayChange)
        XCTAssertTrue(change.string.hasPrefix("+5% ($2"), change.string)
        XCTAssertTrue(change.string.hasSuffix(")"), change.string)
        XCTAssertEqual(change.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, FWSunlit.Palette.priceUp)
        let valueColor = change.attribute(.foregroundColor, at: "+5% ".count, effectiveRange: nil) as? UIColor
        XCTAssertNotNil(valueColor)
        XCTAssertNotEqual(valueColor, FWSunlit.Palette.priceUp)

        XCTAssertNotNil(user.balanceCaption)
        XCTAssertEqual(user.balanceCaption, info.allHoldingsCaption)
    }

    func testDayChangeColourFollowsDirection() throws {
        let factory = try CovJUiProfileModels.factory(.none, settings: InMemorySettingsManager(), test: self)
        let falling = try XCTUnwrap(model(factory, balance: balance(percent: -0.02, value: -1)).profileUserViewModel.dayChange)
        XCTAssertTrue(falling.string.hasPrefix("-2%"), falling.string)
        XCTAssertEqual(falling.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, FWSunlit.Palette.priceDown)

        let flat = model(factory, balance: balance(percent: 0, value: 0)).profileUserViewModel
        XCTAssertEqual(flat.dayChange?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, FWSunlit.Palette.textSecondary)
        XCTAssertNil(flat.balanceCaption, "nothing hidden, no caption")
    }

    // IrohaConnectReleasePolicy.enabledForTests exists only in DEBUG builds.
    #if DEBUG
        func testAllOptionsReflectSettingsWarningsTonAndIroha() throws {
            let settings: SettingsManagerProtocol = InMemorySettingsManager()
            settings.biometryEnabled = true
            let factory = try CovJUiProfileModels.factory(
                .faceId, settings: settings, policy: .enabledForTests, sound: false, haptics: true, test: self
            )
            let viewModel = model(
                factory,
                wallet: AccountGenerator.generateMetaAccount(with: [CovJUiProfileModels.tonAccount()]),
                currency: .euro(),
                issues: [.missingAccount(chains: [])]
            )
            let rows = viewModel.profileOptionViewModel
            XCTAssertEqual(rows.compactMap(\.option), ProfileOption.allCases)
            func row(_ option: ProfileOption) -> ProfileOptionViewModelProtocol? { rows.first { $0.option == option } }

            XCTAssertEqual(row(.biometry)?.title, "Face ID")
            XCTAssertEqual(CovJUiProfileModels.switchState(row(.biometry)), true)
            XCTAssertEqual(row(.accountList)?.title, R.string.localizable.profileWalletsTitle(preferredLanguages: languages))
            XCTAssertNotNil(row(.accountList)?.accessoryImage, "a missing account is flagged")
            XCTAssertEqual(row(.currency)?.title, R.string.localizable.commonCurrency(preferredLanguages: languages))
            XCTAssertEqual(row(.currency)?.accessoryTitle, "EUR")
            XCTAssertEqual(row(.language)?.title, R.string.localizable.languageTitle(preferredLanguages: languages))
            XCTAssertEqual(row(.language)?.accessoryTitle, "English")
            XCTAssertEqual(row(.tonConnect)?.title, "TonConnect")
            XCTAssertNil(row(.tonConnect)?.accessoryTitle)
            XCTAssertEqual(row(.irohaConnect)?.title, "IrohaConnect")
            XCTAssertEqual(row(.irohaConnect)?.accessoryTitle, "SORA 3")
            XCTAssertEqual(row(.walletConnect)?.title, "Wallet connect")
            XCTAssertNil(CovJUiProfileModels.switchState(row(.walletConnect)))
            XCTAssertEqual(row(.networkAssets)?.title, "Networks & Assets")
            XCTAssertEqual(row(.changePincode)?.title, R.string.localizable.profilePincodeChangeTitle(preferredLanguages: languages))
            XCTAssertEqual(row(.polkaswapDisclaimer)?.title, R.string.localizable.polkaswapDisclaimerSettings(preferredLanguages: languages))
            XCTAssertEqual(row(.about)?.title, R.string.localizable.aboutTitle(preferredLanguages: languages))
            XCTAssertEqual(row(.previousData)?.title, RecoveryText.string("previous_data"))
            XCTAssertEqual(row(.emergencyMaterial)?.title, RecoveryText.string("export"))
            XCTAssertEqual(row(.soundEffects)?.title, "Sound effects")
            XCTAssertEqual(CovJUiProfileModels.switchState(row(.soundEffects)), false)
            XCTAssertEqual(row(.hapticFeedback)?.title, "Haptic feedback")
            XCTAssertEqual(CovJUiProfileModels.switchState(row(.hapticFeedback)), true)

            XCTAssertEqual(viewModel.logoutViewModel.title, R.string.localizable.profileLogoutTitle(preferredLanguages: languages))
            XCTAssertNil(viewModel.logoutViewModel.option)
            XCTAssertNotNil(viewModel.logoutViewModel.icon)
            XCTAssertEqual(viewModel.profileUserViewModel.fiatBalance, "")
            XCTAssertNil(viewModel.profileUserViewModel.dayChange)
            XCTAssertNil(viewModel.profileUserViewModel.balanceCaption)
        }
    #endif

    func testTouchIdWithoutTonAccountOrIssuesUsesDefaults() throws {
        let factory = try CovJUiProfileModels.factory(.touchId, settings: InMemorySettingsManager(), test: self)
        let rows = model(factory).profileOptionViewModel
        // IrohaConnect is on in production builds, so its row is listed by default.
        XCTAssertEqual(rows.compactMap(\.option), ProfileOption.allCases)
        func row(_ option: ProfileOption) -> ProfileOptionViewModelProtocol? { rows.first { $0.option == option } }

        XCTAssertEqual(row(.biometry)?.title, "Touch ID")
        XCTAssertEqual(CovJUiProfileModels.switchState(row(.biometry)), false)
        XCTAssertNil(row(.accountList)?.accessoryImage)
        XCTAssertEqual(row(.tonConnect)?.accessoryTitle, "TON account required")
        XCTAssertEqual(row(.currency)?.accessoryTitle, "USD")
    }

    func testNoBiometryLeavesItsRowOut() throws {
        let factory = try CovJUiProfileModels.factory(.none, settings: InMemorySettingsManager(), test: self)
        let options = model(factory).profileOptionViewModel.compactMap(\.option)
        XCTAssertFalse(options.contains(.biometry))
        // Only biometry is left out: IrohaConnect is on in production builds.
        XCTAssertEqual(options.count, ProfileOption.allCases.count - 1)
    }
}

// MARK: - View controller

final class CovJUiProfileViewControllerTests: XCTestCase {
    private let languages = CovJUiProfileModels.locale.rLanguages

    private func host(_ presenter: CovJUiProfilePresenterSpy) throws -> (ProfileViewController, UIWindow) {
        let controller = ProfileViewController(
            presenter: presenter,
            iconGenerating: UniversalIconGenerator(),
            localizationManager: try XCTUnwrap(LocalizationManager(localization: "en"))
        )
        return (controller, try CovJViewFixture.host(controller))
    }

    private func loadedModel() throws -> ProfileViewModelProtocol {
        try CovJUiProfileModels.factory(.faceId, settings: InMemorySettingsManager(), test: self).createProfileViewModel(
            from: AccountGenerator.generateMetaAccount(),
            locale: CovJUiProfileModels.locale,
            language: Language(code: "en"),
            currency: .defaultCurrency(),
            balance: nil,
            missingAccountIssue: []
        )
    }

    func testLoadingStateHasNoRows() throws {
        let presenter = CovJUiProfilePresenterSpy()
        let (controller, window) = try host(presenter)
        defer { window.isHidden = true }
        XCTAssertTrue(presenter.loadedView === controller)

        let table = controller.rootView.tableView
        XCTAssertEqual(controller.numberOfSections(in: table), 9)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 0)
        XCTAssertFalse(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) is ProfileSectionTableViewCell)
        controller.applyLocalization()
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 1), 0)
    }

    func testLoadedSectionsBuildHeaderDetailsOptionAndLogoutCells() throws {
        let presenter = CovJUiProfilePresenterSpy()
        let (controller, window) = try host(presenter)
        defer { window.isHidden = true }
        let model = try loadedModel()
        controller.didReceive(state: .loaded(model))
        controller.view.layoutIfNeeded()
        let table = controller.rootView.tableView

        // Connections lists WalletConnect, TonConnect and IrohaConnect.
        XCTAssertEqual((0 ..< 9).map { controller.tableView(table, numberOfRowsInSection: $0) }, [2, 1, 1, 3, 2, 5, 2, 1, 1])
        XCTAssertNil(controller.tableView(table, titleForHeaderInSection: 0))
        XCTAssertEqual(controller.tableView(table, titleForHeaderInSection: 1), "Wallets & Accounts")
        XCTAssertEqual(controller.tableView(table, titleForHeaderInSection: 3), "Connections")
        XCTAssertEqual(controller.tableView(table, titleForHeaderInSection: 6), RecoveryText.string("advanced"))
        XCTAssertNil(controller.tableView(table, titleForHeaderInSection: 8))

        let header = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) as? ProfileSectionTableViewCell)
        XCTAssertEqual(header.titleLabel.text, R.string.localizable.profileTitle(preferredLanguages: languages))
        let details = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 1, section: 0)) as? WalletsManagmentTableCell)
        XCTAssertTrue(details.delegate === controller)
        XCTAssertFalse(controller.tableView(table, cellForRowAt: IndexPath(row: 2, section: 0)) is WalletsManagmentTableCell)

        let logout = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 8)) as? ProfileTableViewCell)
        XCTAssertEqual(logout.viewModel?.title, model.logoutViewModel.title)
        XCTAssertTrue(logout.switcher.isHidden)

        let accounts = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 1)) as? ProfileTableViewCell)
        XCTAssertEqual(accounts.viewModel?.option, .accountList)
        XCTAssertFalse(controller.tableView(table, cellForRowAt: IndexPath(row: 5, section: 4)) is ProfileTableViewCell)
        XCTAssertFalse(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 42)) is ProfileTableViewCell)
    }

    func testBiometrySwitchReportsItsOption() throws {
        let presenter = CovJUiProfilePresenterSpy()
        let (controller, window) = try host(presenter)
        defer { window.isHidden = true }
        controller.didReceive(state: .loaded(try loadedModel()))
        controller.view.layoutIfNeeded()
        let table = controller.rootView.tableView

        let biometry = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 1, section: 4)) as? ProfileTableViewCell)
        XCTAssertEqual(biometry.viewModel?.option, .biometry)
        XCTAssertFalse(biometry.switcher.isHidden)
        XCTAssertEqual(biometry.switcher.tag, Int(ProfileOption.biometry.rawValue))
        biometry.switcher.isOn = true
        biometry.switcher.sendActions(for: .valueChanged)
        XCTAssertEqual(presenter.switches, ["true:\(ProfileOption.biometry.rawValue)"])
    }

    func testHeightsFootersAndSelectionsReachPresenter() throws {
        let presenter = CovJUiProfilePresenterSpy()
        let (controller, window) = try host(presenter)
        defer { window.isHidden = true }
        controller.didReceive(state: .loaded(try loadedModel()))
        controller.view.layoutIfNeeded()
        let table = controller.rootView.tableView

        XCTAssertEqual(controller.tableView(table, heightForRowAt: IndexPath(row: 0, section: 0)), 56)
        XCTAssertEqual(controller.tableView(table, heightForRowAt: IndexPath(row: 1, section: 0)), 86)
        XCTAssertEqual(controller.tableView(table, heightForRowAt: IndexPath(row: 2, section: 0)), 48)
        XCTAssertEqual(controller.tableView(table, heightForRowAt: IndexPath(row: 0, section: 5)), 48)
        let footer = try XCTUnwrap(controller.tableView(table, viewForFooterInSection: 1))
        XCTAssertEqual(footer.frame.height, 20)
        XCTAssertEqual(footer.backgroundColor, .clear)
        XCTAssertEqual(controller.tableView(table, heightForFooterInSection: 3), 20)

        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(presenter.detailsCalls, 0)
        controller.tableView(table, didSelectRowAt: IndexPath(row: 1, section: 0))
        XCTAssertEqual(presenter.detailsCalls, 1)
        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 8))
        XCTAssertEqual(presenter.logouts, 1)
        controller.tableView(table, didSelectRowAt: IndexPath(row: 1, section: 3))
        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 7))
        XCTAssertEqual(presenter.options, [.tonConnect, .about])

        controller.didTapOptionsCell(with: nil)
        XCTAssertEqual(presenter.detailsCalls, 2)
    }
}
