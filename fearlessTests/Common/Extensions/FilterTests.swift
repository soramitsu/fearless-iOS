import XCTest
@testable import fearless
import BigInt
import FearlessFoundation
import FearlessSecureStorage
import IrohaCrypto
import JSONRPC
import RobinHood
import SSFModels
import enum SSFUtils.Era
import enum SSFUtils.JSON
import enum SSFUtils.MultiAddress
import enum SSFUtils.MultiSignature
import struct SSFUtils.RuntimeCall
import TonAPI
import UIKit
import Web3
import WalletConnectPairing
import WalletConnectUtils

final class CommonExtensionUtilityTests: XCTestCase {
    func testDummySigner_whenSigningWithSupportedCryptoTypes_thenProducesSignatures() throws {
        let seed = Data(repeating: 2, count: 32)
        let originalData = try XCTUnwrap("this is a message".data(using: .utf8))

        let sr25519Signer = try DummySigner(cryptoType: .sr25519, seed: seed)
        let sr25519Signature = try sr25519Signer.sign(originalData)
        XCTAssertFalse(sr25519Signature.rawData().isEmpty)
        guard case let .sr25519(secretKeyData, publicKeyData) = sr25519Signer.type else {
            return XCTFail("SR25519 dummy signer expected")
        }
        XCTAssertFalse(secretKeyData.isEmpty)
        XCTAssertFalse(publicKeyData.isEmpty)

        let ed25519Signer = try DummySigner(cryptoType: .ed25519, seed: seed)
        let ed25519Signature = try ed25519Signer.sign(originalData)
        XCTAssertFalse(ed25519Signature.rawData().isEmpty)
        guard case let .ed25519(storedEdSeed) = ed25519Signer.type else {
            return XCTFail("ED25519 dummy signer expected")
        }
        XCTAssertEqual(storedEdSeed, seed)

        let ecdsaSigner = try DummySigner(cryptoType: .ecdsa, seed: seed)
        let ecdsaSignature = try ecdsaSigner.sign(originalData)
        XCTAssertFalse(ecdsaSignature.rawData().isEmpty)
        guard case let .ecdsa(storedEcdsaSeed) = ecdsaSigner.type else {
            return XCTFail("ECDSA dummy signer expected")
        }
        XCTAssertEqual(storedEcdsaSeed, seed)
    }

    func testNSLockWith_whenBlockReturnsValue_thenReturnsBlockResult() {
        let lock = NSLock()
        var value = 1

        let result = lock.with {
            value += 1
            return value
        }

        XCTAssertEqual(result, 2)
        XCTAssertEqual(value, 2)
    }

    func testIntFirstDivider_whenDividerExists_thenReturnsFirstMatchingDivider() {
        XCTAssertEqual(10.firstDivider(from: [3, 5, 2]), 5)
        XCTAssertNil(11.firstDivider(from: [2, 3, 5]))
    }

    func testSequenceWithoutDuplicates_whenSequenceHasRepeatedValues_thenKeepsFirstOccurrenceOrder() {
        let values = ["xor", "val", "xor", "dot", "val"]

        XCTAssertEqual(values.withoutDuplicates(), ["xor", "val", "dot"])
    }

    func testBoolInverted_whenCalled_thenReturnsOppositeValue() {
        XCTAssertFalse(true.inverted())
        XCTAssertTrue(false.inverted())
    }

    func testDecimalFormattingHelpers_whenLocaleProvided_thenUseExpectedFormattingStyles() {
        let locale = Locale(identifier: "en_US_POSIX")

        XCTAssertEqual(Decimal(string: "1234.5")?.stringWithPointSeparator, "1234.5")
        XCTAssertEqual(Decimal(string: "1.2")?.toString(locale: locale), "1.200")
        XCTAssertEqual(Decimal(string: "0.125")?.percentString(locale: locale), "+12.5%")
    }

    func testNetworkTimestampFormatter_whenParsingFixedFormats_thenUsesStableLocale() {
        let timestamp = "2024-01-02T03:04:05.000Z"

        XCTAssertEqual(
            DateFormatter.networkTimestampInSeconds(from: timestamp, using: DateFormatter.giantsquidDate),
            1_704_164_645
        )
        XCTAssertEqual(
            DateFormatter.networkTimestampInSeconds(from: timestamp, using: DateFormatter.alchemyDate),
            1_704_164_645
        )
        XCTAssertEqual(
            DateFormatter.networkTimestampString(from: 1_704_164_645, using: DateFormatter.giantsquidDate),
            "2024-01-02T03:04:05.000000+0000"
        )
        XCTAssertEqual(
            DateFormatter.networkTimestampInSeconds(from: "not-a-date", using: DateFormatter.giantsquidDate),
            0
        )
    }

    func testDecimalString_whenSignificantFractionDigitsRequested_thenKeepsLeadingFractionZeros() {
        XCTAssertEqual(decimal("12.3456").string(maximumFractionDigits: 2), "12.34")
        XCTAssertEqual(decimal("12.003456").string(maximumFractionDigits: 2), "12.0034")
        XCTAssertEqual(decimal("0.00012").string(maximumFractionDigits: 2), "0.00012")
        XCTAssertEqual(decimal("12").string(maximumFractionDigits: 2), "12")
    }

    func testAccountImportSourceTitle_whenLocalized_thenMapsAllSources() {
        let locale = Locale(identifier: "en_US_POSIX")
        let titles = AccountImportSource.allCases.map { $0.titleForLocale(locale) }

        XCTAssertEqual(titles, [
            R.string.localizable.importMnemonic(preferredLanguages: locale.rLanguages),
            R.string.localizable.importRawSeed(preferredLanguages: locale.rLanguages),
            R.string.localizable.importRecoveryJson(preferredLanguages: locale.rLanguages)
        ])
        XCTAssertEqual(Set(titles).count, titles.count)
    }

    func testExportOptionTitle_whenEthereumContextChanges_thenMapsContextualTitles() {
        let locale = Locale(identifier: "en_US_POSIX")

        XCTAssertEqual(
            ExportOption.mnemonic.titleForLocale(locale, ethereumBased: nil),
            R.string.localizable.importMnemonic(preferredLanguages: locale.rLanguages)
        )
        XCTAssertEqual(
            ExportOption.seed.titleForLocale(locale, ethereumBased: nil),
            R.string.localizable.importRawSeed(preferredLanguages: locale.rLanguages)
        )
        XCTAssertEqual(
            ExportOption.seed.titleForLocale(locale, ethereumBased: true),
            R.string.localizable.accountImportEthereumRawSeedPlaceholder(preferredLanguages: locale.rLanguages)
        )
        XCTAssertEqual(
            ExportOption.seed.titleForLocale(locale, ethereumBased: false),
            R.string.localizable.accountImportSubstrateRawSeedPlaceholder(preferredLanguages: locale.rLanguages)
        )
        XCTAssertEqual(
            ExportOption.keystore.titleForLocale(locale, ethereumBased: nil),
            R.string.localizable.importRecoveryJson(preferredLanguages: locale.rLanguages)
        )
        XCTAssertEqual(
            ExportOption.keystore.titleForLocale(locale, ethereumBased: true),
            R.string.localizable.importEthereumRecoveryJson(preferredLanguages: locale.rLanguages)
        )
        XCTAssertEqual(
            ExportOption.keystore.titleForLocale(locale, ethereumBased: false),
            R.string.localizable.importSubstrateRecoveryJson(preferredLanguages: locale.rLanguages)
        )
    }

    func testErrorPresentable_whenKnownErrorsProvided_thenPresentsExpectedAlertContent() {
        let locale = Locale(identifier: "en_US_POSIX")
        let customPresenter = SheetAlertPresentableSpy()
        let customContent = ErrorContent(title: "Custom title", message: "Custom message")

        XCTAssertTrue(customPresenter.present(
            error: TestErrorContentConvertible(content: customContent),
            from: nil,
            locale: locale
        ))
        XCTAssertEqual(customPresenter.presentedMessages.last?.title, customContent.title)
        XCTAssertEqual(customPresenter.presentedMessages.last?.message, customContent.message)
        XCTAssertEqual(
            customPresenter.presentedMessages.last?.closeAction,
            R.string.localizable.commonClose(preferredLanguages: locale.rLanguages)
        )

        let operationPresenter = SheetAlertPresentableSpy()
        XCTAssertTrue(operationPresenter.present(
            error: BaseOperationError.parentOperationCancelled,
            from: nil,
            locale: locale
        ))
        XCTAssertEqual(
            operationPresenter.presentedMessages.last?.title,
            R.string.localizable.operationErrorTitle(preferredLanguages: locale.rLanguages)
        )
        XCTAssertEqual(
            operationPresenter.presentedMessages.last?.message,
            R.string.localizable.operationErrorMessage(preferredLanguages: locale.rLanguages)
        )

        let connectionPresenter = SheetAlertPresentableSpy()
        XCTAssertTrue(connectionPresenter.present(
            error: NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet),
            from: nil,
            locale: locale
        ))
        XCTAssertEqual(
            connectionPresenter.presentedMessages.last?.title,
            R.string.localizable.connectionErrorTitle(preferredLanguages: locale.rLanguages)
        )
        XCTAssertEqual(
            connectionPresenter.presentedMessages.last?.message,
            R.string.localizable.connectionErrorMessage(preferredLanguages: locale.rLanguages)
        )

        let unknownPresenter = SheetAlertPresentableSpy()
        XCTAssertFalse(unknownPresenter.present(
            error: NSError(domain: "fearless.tests", code: -1),
            from: nil,
            locale: locale
        ))
        XCTAssertTrue(unknownPresenter.presentedMessages.isEmpty)
    }

    func testChainAccountModelToAddress_whenSubstrateAndEthereumAccountsProvided_thenUsesExpectedFormats() throws {
        let substrateAccountId = try AddressTestConstants.kusamaAddress.toAccountId()
        let substrateAccount = ChainAccountModel(
            chainId: "kusama",
            accountId: substrateAccountId,
            publicKey: substrateAccountId,
            cryptoType: CryptoType.sr25519.rawValue,
            ethereumBased: false
        )

        XCTAssertEqual(substrateAccount.toAddress(addressPrefix: 2), AddressTestConstants.kusamaAddress)

        let ethereumAccountId = try AccountId(hexStringSSF: AddressTestConstants.ethereumAddres)
        let ethereumAccount = ChainAccountModel(
            chainId: "ethereum",
            accountId: ethereumAccountId,
            publicKey: ethereumAccountId,
            cryptoType: CryptoType.ecdsa.rawValue,
            ethereumBased: true
        )

        XCTAssertEqual(ethereumAccount.toAddress(addressPrefix: 0), AddressTestConstants.ethereumAddres)
    }

    func testChainConnectionVisibilityHelper_whenVisibilityAndRequiredFeaturesProvided_thenUsesExpectedRules() throws {
        let helper = ChainConnectionVisibilityHelper()
        let asset = makeHistoryAsset(id: "xor")
        let chain = makeChain(chainId: "sora-mainnet", assets: [asset])
        let chainAssetId = try XCTUnwrap(chain.chainAssets.first?.identifier)

        XCTAssertTrue(helper.shouldHaveConnetion(chain, wallet: nil))
        XCTAssertTrue(helper.shouldHaveConnetion(chain, wallet: makeMetaAccount()))
        XCTAssertFalse(helper.shouldHaveConnetion(
            chain,
            wallet: makeMetaAccount(assetsVisibility: [AssetVisibility(assetId: chainAssetId, hidden: true)])
        ))
        XCTAssertTrue(helper.shouldHaveConnetion(
            chain,
            wallet: makeMetaAccount(assetsVisibility: [AssetVisibility(assetId: chainAssetId, hidden: false)])
        ))
        XCTAssertFalse(helper.shouldHaveConnetion(
            chain,
            wallet: makeMetaAccount(assetsVisibility: [AssetVisibility(assetId: "other-chain : xor", hidden: false)])
        ))

        let hiddenAssetWallet = makeMetaAccount(assetsVisibility: [AssetVisibility(assetId: chainAssetId, hidden: true)])
        XCTAssertTrue(helper.shouldHaveConnetion(
            makeChain(chainId: "chainlink", assets: [asset], options: [.chainlinkProvider]),
            wallet: hiddenAssetWallet
        ))
        XCTAssertTrue(helper.shouldHaveConnetion(
            makeChain(chainId: "pool-staking", assets: [asset], options: [.poolStaking]),
            wallet: hiddenAssetWallet
        ))
        XCTAssertTrue(helper.shouldHaveConnetion(
            makeChain(chainId: "relay-staking", assets: [makeHistoryAsset(staking: .relayChain)]),
            wallet: hiddenAssetWallet
        ))
        XCTAssertTrue(helper.shouldHaveConnetion(
            makeChain(chainId: "para-staking", assets: [makeHistoryAsset(staking: .paraChain)]),
            wallet: hiddenAssetWallet
        ))
    }

    func testChainDateCalculator_whenPeriodsProvided_thenComputesLeasingDurations() throws {
        let calculator = ChainDateCalculator()
        let metadata = CrowdloanMetadata(
            blockNumber: 100,
            blockDuration: 6000,
            leasingPeriod: 10,
            leasingOffset: 0
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))

        let futureInterval = try XCTUnwrap(calculator.intervalTillPeriod(
            12,
            metadata: metadata,
            calendar: calendar
        ))
        XCTAssertEqual(futureInterval.duration, 120)
        XCTAssertEqual(futureInterval.tillDate.timeIntervalSinceNow, 120, accuracy: 5)

        let pastInterval = try XCTUnwrap(calculator.intervalTillPeriod(
            8,
            metadata: metadata,
            calendar: calendar
        ))
        XCTAssertEqual(pastInterval.duration, 0)
        XCTAssertLessThan(pastInterval.tillDate.timeIntervalSinceNow, 0)

        let slotDifference = try XCTUnwrap(calculator.differenceBetweenLeasingSlots(
            firstPeriod: 12,
            lastPeriod: 14,
            metadata: metadata,
            calendar: calendar
        ))
        XCTAssertEqual(slotDifference.duration, 180)
        XCTAssertEqual(slotDifference.tillDate.timeIntervalSinceNow, 300, accuracy: 5)
    }

    func testNumberFormatterStaticPresets_whenCreated_thenExposeExpectedStylesAndOutput() {
        let locale = Locale(identifier: "en_US_POSIX")
        let amount = NumberFormatter.amount
        amount.locale = locale
        amount.maximumFractionDigits = 2

        XCTAssertEqual(amount.numberStyle, .decimal)
        XCTAssertEqual(amount.minimumIntegerDigits, 1)
        XCTAssertTrue(amount.usesGroupingSeparator)
        XCTAssertEqual(amount.roundingMode, .down)
        XCTAssertFalse(amount.alwaysShowsDecimalSeparator)
        XCTAssertEqual(amount.string(from: NSDecimalNumber(string: "1234.569")), "1,234.56")

        let percentBase = NumberFormatter.percentBase
        percentBase.locale = locale
        XCTAssertEqual(percentBase.numberStyle, .percent)
        XCTAssertEqual(percentBase.minimumFractionDigits, 2)
        XCTAssertEqual(percentBase.maximumFractionDigits, 2)
        XCTAssertEqual(percentBase.roundingMode, .down)
        XCTAssertEqual(percentBase.string(from: NSDecimalNumber(string: "0.1299")), "12.99%")

        let percentPlain = NumberFormatter.percentPlain
        percentPlain.locale = locale
        XCTAssertEqual(percentPlain.multiplier, NSNumber(value: 1))
        XCTAssertEqual(percentPlain.string(from: NSDecimalNumber(string: "12.999")), "12.99%")

        let percent = NumberFormatter.percent
        percent.locale = locale
        XCTAssertEqual(percent.string(from: NSDecimalNumber(string: "0.1299")), "12.99%")

        let signedPercent = NumberFormatter.signedPercent
        signedPercent.locale = locale
        XCTAssertEqual(signedPercent.positivePrefix, signedPercent.plusSign)
        XCTAssertEqual(signedPercent.string(from: NSDecimalNumber(string: "0.1234")), "+12.34%")

        let percentPlainAPY = NumberFormatter.percentPlainAPY
        percentPlainAPY.locale = locale
        XCTAssertEqual(percentPlainAPY.percentSymbol, "% APY")
        XCTAssertEqual(percentPlainAPY.multiplier, NSNumber(value: 1))
        XCTAssertEqual(percentPlainAPY.string(from: NSDecimalNumber(string: "12.345")), "12.34% APY")

        let percentPlainAPR = NumberFormatter.percentPlainAPR
        percentPlainAPR.locale = locale
        XCTAssertEqual(percentPlainAPR.percentSymbol, "% APR")
        XCTAssertEqual(percentPlainAPR.multiplier, NSNumber(value: 1))
        XCTAssertEqual(percentPlainAPR.string(from: NSDecimalNumber(string: "12.345")), "12.34% APR")

        let percentAPY = NumberFormatter.percentAPY
        percentAPY.locale = locale
        XCTAssertEqual(percentAPY.percentSymbol, "% APY")
        XCTAssertEqual(percentAPY.string(from: NSDecimalNumber(string: "0.12345")), "12.34% APY")

        let positivePercentAPY = NumberFormatter.positivePercentAPY
        positivePercentAPY.locale = locale
        XCTAssertEqual(positivePercentAPY.positivePrefix, positivePercentAPY.plusSign)
        XCTAssertEqual(positivePercentAPY.string(from: NSDecimalNumber(string: "0.12345")), "+12.34% APY")

        let positivePercentAPR = NumberFormatter.positivePercentAPR
        positivePercentAPR.locale = locale
        XCTAssertEqual(positivePercentAPR.positivePrefix, positivePercentAPR.plusSign)
        XCTAssertEqual(positivePercentAPR.string(from: NSDecimalNumber(string: "0.12345")), "+12.34% APR")

        let percentSingle = NumberFormatter.percentSingle
        percentSingle.locale = locale
        XCTAssertEqual(percentSingle.percentSymbol, "%")
        XCTAssertEqual(percentSingle.minimumFractionDigits, 0)
        XCTAssertEqual(percentSingle.string(from: NSDecimalNumber(string: "0.12345")), "12.34%")

        let quantity = NumberFormatter.quantity
        quantity.locale = locale
        XCTAssertEqual(quantity.maximumFractionDigits, 0)
        XCTAssertEqual(quantity.string(from: NSDecimalNumber(string: "1234.56")), "1,235")

        let fiat = NumberFormatter.fiat
        fiat.locale = locale
        XCTAssertEqual(fiat.roundingMode, .floor)
        XCTAssertEqual(fiat.maximumFractionDigits, 2)
        XCTAssertTrue(fiat.usesSignificantDigits)

        let polkaswapBalance = NumberFormatter.polkaswapBalance
        polkaswapBalance.locale = locale
        XCTAssertEqual(polkaswapBalance.roundingMode, .floor)
        XCTAssertEqual(polkaswapBalance.maximumFractionDigits, 4)

        let token = NumberFormatter.token(rounding: .up, usesIntGrouping: true)
        token.locale = locale
        XCTAssertEqual(token.minimumFractionDigits, 3)
        XCTAssertEqual(token.maximumFractionDigits, 8)
        XCTAssertEqual(token.roundingMode, .up)
        XCTAssertTrue(token.usesGroupingSeparator)
    }

    func testNumberFormatterUsageCases_whenCreated_thenConfigureDefaultFormatterContracts() {
        let locale = Locale(identifier: "en_US_POSIX")

        let listCrypto = NumberFormatter.formatter(
            for: .listCrypto,
            locale: locale,
            rounding: .up,
            usesIntGrouping: true
        )
        XCTAssertEqual(listCrypto.locale, locale)
        XCTAssertEqual(listCrypto.minimumFractionDigits, 3)
        XCTAssertEqual(listCrypto.maximumFractionDigits, 8)
        XCTAssertEqual(listCrypto.roundingMode, .up)
        XCTAssertTrue(listCrypto.usesGroupingSeparator)

        let customListCrypto = NumberFormatter.formatter(
            for: .listCryptoWith(minimumFractionDigits: 1, maximumFractionDigits: 4),
            locale: locale,
            rounding: .down,
            usesIntGrouping: false
        )
        XCTAssertEqual(customListCrypto.minimumFractionDigits, 1)
        XCTAssertEqual(customListCrypto.maximumFractionDigits, 4)
        XCTAssertEqual(customListCrypto.roundingMode, .down)
        XCTAssertFalse(customListCrypto.usesGroupingSeparator)

        let detailsCrypto = NumberFormatter.formatter(
            for: .detailsCrypto,
            locale: locale,
            rounding: .ceiling,
            usesIntGrouping: true
        )
        XCTAssertEqual(detailsCrypto.minimumFractionDigits, 0)
        XCTAssertEqual(detailsCrypto.maximumFractionDigits, 8)
        XCTAssertEqual(detailsCrypto.roundingMode, .ceiling)
        XCTAssertTrue(detailsCrypto.usesGroupingSeparator)

        let fiat = NumberFormatter.formatter(for: .fiat, locale: locale)
        XCTAssertEqual(fiat.numberStyle, .decimal)
        XCTAssertEqual(fiat.minimumIntegerDigits, 1)
        XCTAssertEqual(fiat.maximumFractionDigits, Int.max)
        XCTAssertTrue(fiat.usesGroupingSeparator)
        XCTAssertTrue(fiat.usesSignificantDigits)

        let percent = NumberFormatter.formatter(for: .percent, locale: locale)
        XCTAssertEqual(percent.numberStyle, .percent)
        XCTAssertEqual(percent.minimumFractionDigits, 2)
        XCTAssertEqual(percent.maximumFractionDigits, 2)
        XCTAssertEqual(percent.roundingMode, .down)

        let inputCrypto = NumberFormatter.formatter(for: .inputCrypto, locale: locale)
        XCTAssertEqual(inputCrypto.numberStyle, .decimal)
        XCTAssertEqual(inputCrypto.minimumIntegerDigits, 1)
        XCTAssertEqual(inputCrypto.maximumFractionDigits, 8)
        XCTAssertFalse(inputCrypto.usesGroupingSeparator)

        let inputFiat = NumberFormatter.formatter(for: .inputFiat, locale: locale)
        XCTAssertEqual(inputFiat.numberStyle, .decimal)
        XCTAssertEqual(inputFiat.minimumIntegerDigits, 1)
        XCTAssertEqual(inputFiat.maximumFractionDigits, 2)
        XCTAssertTrue(inputFiat.usesGroupingSeparator)

        let decimalFormatter = NumberFormatter.decimalFormatter(
            precision: 6,
            rounding: .floor,
            usesIntGrouping: false,
            usageCase: .inputFiat,
            locale: locale
        )
        XCTAssertEqual(decimalFormatter.numberStyle, .decimal)
        XCTAssertEqual(decimalFormatter.minimumIntegerDigits, 1)
        XCTAssertEqual(decimalFormatter.roundingMode, .floor)
        XCTAssertFalse(decimalFormatter.usesGroupingSeparator)
        XCTAssertFalse(decimalFormatter.alwaysShowsDecimalSeparator)
    }

    func testNormalizedIpfsURL_whenURLUsesIpfsScheme_thenMapsToGatewayURL() throws {
        let ipfsURL = try XCTUnwrap(URL(string: "ipfs://bafybeigdyrzt/path"))
        let httpsURL = try XCTUnwrap(URL(string: "https://ipfs.io/ipfs/bafybeigdyrzt"))

        XCTAssertEqual(
            ipfsURL.normalizedIpfsURL?.absoluteString,
            "https://ipfs.io/ipfs/bafybeigdyrzt/path"
        )
        XCTAssertEqual(httpsURL.normalizedIpfsURL, httpsURL)
    }

    func testUIColorHexHelpers_whenColorCanExposeRGBComponents_thenReturnsUppercaseHexValues() {
        let color = UIColor(red: 1, green: 0, blue: 0, alpha: 1)

        XCTAssertEqual(color.hexRGB, "#FF0000")
        XCTAssertEqual(color.hexRGBA, "#FF0000FF")
    }

    func testUIKitUtilityExtensions_whenApplied_thenUpdateViewStateAndSizing() {
        let control = UIControl()
        control.disable(with: 0.33)
        XCTAssertFalse(control.isEnabled)
        XCTAssertEqual(control.alpha, 0.33, accuracy: 0.001)

        control.enable()
        XCTAssertTrue(control.isEnabled)
        XCTAssertEqual(control.alpha, 1)

        let separatorColor = UIColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1)
        XCTAssertEqual(UIView.createSeparator(color: separatorColor).backgroundColor, separatorColor)

        let firstView = UIView()
        let secondView = UIView()
        let deactivatable = TestDeactivatableView(deactivatableViews: [firstView, secondView])
        deactivatable.setDeactivated(true)
        XCTAssertEqual(firstView.alpha, 0.25)
        XCTAssertEqual(secondView.alpha, 0.25)

        deactivatable.setDeactivated(false)
        XCTAssertEqual(firstView.alpha, 1)
        XCTAssertEqual(secondView.alpha, 1)
    }

    func testTopViewController_whenNestedInPresentationTabAndNavigation_thenFindsVisibleController() {
        let root = UIViewController()
        let visible = UIViewController()
        let navigationController = UINavigationController()
        navigationController.viewControllers = [root, visible]

        let tabController = UITabBarController()
        tabController.viewControllers = [UIViewController(), navigationController]
        tabController.selectedIndex = 1

        let presenter = TestPresentingViewController(presentedViewController: tabController)

        XCTAssertTrue(UIApplication.topViewController(controller: presenter) === visible)
        XCTAssertNil(UIApplication.topViewController(controller: nil))
    }

    func testFearlessLoadingViewFactory_whenCreated_thenAppliesAppLoadingContract() {
        let loadingView = FearlessLoadingViewFactory.createLoadingView()
        let fallbackLoadingView = FearlessLoadingViewFactory.createLoadingView(indicatorImage: nil)

        XCTAssertEqual(loadingView.frame, UIScreen.main.bounds)
        XCTAssertEqual(loadingView.contentSize, CGSize(width: 120, height: 120))
        XCTAssertEqual(loadingView.animationDuration, 1)
        XCTAssertNotNil(loadingView.indicatorImage)
        XCTAssertNotNil(fallbackLoadingView.indicatorImage)
        XCTAssertEqual(fallbackLoadingView.indicatorImage?.size, .zero)
        XCTAssertEqual(
            loadingView.backgroundColor?.cgColor.alpha ?? 0,
            0.19,
            accuracy: 0.001
        )
        XCTAssertEqual(
            loadingView.contentBackgroundColor.cgColor.alpha,
            0.04,
            accuracy: 0.001
        )
    }

    func testNumberedLabelAndSwitchSizing_whenConfigured_thenApplyStableViewContracts() {
        let numberedLabel = NumberedLabel(with: 7)
        numberedLabel.textLabel.text = "Read the warning"

        numberedLabel.layoutIfNeeded()
        numberedLabel.layoutIfNeeded()

        XCTAssertEqual(numberedLabel.numberLabel.text, "7.")
        XCTAssertEqual(numberedLabel.textLabel.text, "Read the warning")
        XCTAssertEqual(numberedLabel.textLabel.numberOfLines, 0)
        XCTAssertEqual(numberedLabel.subviews.filter { $0 === numberedLabel.numberLabel }.count, 1)
        XCTAssertEqual(numberedLabel.subviews.filter { $0 === numberedLabel.textLabel }.count, 1)
        XCTAssertEqual(
            numberedLabel.numberLabel
                .contentCompressionResistancePriority(for: .horizontal)
                .rawValue,
            UILayoutPriority.defaultHigh.rawValue
        )
        XCTAssertEqual(
            numberedLabel.textLabel
                .contentCompressionResistancePriority(for: .horizontal)
                .rawValue,
            UILayoutPriority.defaultLow.rawValue
        )

        let toggle = UISwitch()
        toggle.set(width: 102, height: 62)

        XCTAssertEqual(toggle.transform.a, 2, accuracy: 0.001)
        XCTAssertEqual(toggle.transform.d, 2, accuracy: 0.001)
    }

    func testAmountInputAccessoryActions_whenSelected_thenNotifyDelegateWithExpectedValues() {
        let view = AmountInputAccessoryView()
        let delegate = AmountInputAccessoryDelegateRecorder()
        view.actionDelegate = delegate

        view.actionSelect100()
        view.actionSelect75()
        view.actionSelect50()
        view.actionSelect25()
        view.actionSelect01()
        view.actionSelect05()
        view.actionSelectDone()

        XCTAssertEqual(delegate.percentages, [1.0, 0.75, 0.5, 0.25, 0.1, 0.5])
        XCTAssertEqual(delegate.doneCallCount, 1)
        XCTAssertTrue(delegate.selectedViews.allSatisfy { $0 === view })
        XCTAssertTrue(delegate.doneViews.allSatisfy { $0 === view })
    }

    func testInteractionDismissClosure_whenAddedAndInvoked_thenStoresClosureOnController() {
        let viewController = UIViewController()
        var dismissCount = 0

        viewController.addOnInteractionDismiss {
            dismissCount += 1
        }
        viewController.onInteractionDismiss()

        XCTAssertEqual(dismissCount, 1)

        viewController.addOnInteractionDismiss {
            dismissCount += 10
        }
        viewController.onInteractionDismiss()

        XCTAssertEqual(dismissCount, 11)
    }

    func testFontDynamicSize_whenScreenRatioChanges_thenCapsAtOriginalRequestedSize() {
        let font = UIFont.systemFont(ofSize: 20)
        let screenHeight = UIScreen.main.bounds.size.height

        let scaledFont = font.dynamicSize(fromSize: 20, figmaScreenHeight: screenHeight * 2)
        let cappedFont = font.dynamicSize(fromSize: 20, figmaScreenHeight: 1)

        XCTAssertEqual(scaledFont.pointSize, 10, accuracy: 0.01)
        XCTAssertEqual(cappedFont.pointSize, 20, accuracy: 0.01)
    }

    func testRefreshControlAndSelfSizingTable_whenStateChanges_thenExposeExpectedValues() {
        let refreshControl = UIRefreshControl(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
        let tableView = UITableView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

        refreshControl.programaticallyBeginRefreshing(in: tableView)

        XCTAssertEqual(tableView.contentOffset.y, -44, accuracy: 0.001)

        let selfSizingTableView = SelfSizingTableView()
        selfSizingTableView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 18, right: 0)
        selfSizingTableView.contentSize = CGSize(width: 240, height: 320)

        XCTAssertEqual(selfSizingTableView.intrinsicContentSize.width, 240)
        XCTAssertEqual(selfSizingTableView.intrinsicContentSize.height, 350)
    }

    func testNetworkUtilityRequests_whenInitialized_thenPreserveConfiguration() throws {
        let body = try data(from: #"{"jsonrpc":"2.0"}"#)
        let request = AlchemyRequest(body: body)

        XCTAssertEqual(request.baseURL.scheme, "https")
        XCTAssertEqual(request.baseURL.host, "eth-mainnet.g.alchemy.com")
        XCTAssertTrue(request.baseURL.path.hasPrefix("/v2"))
        XCTAssertEqual(request.method, .post)
        XCTAssertNil(request.endpoint)
        XCTAssertNil(request.queryItems)
        XCTAssertEqual(request.headers.map(\.field), ["accept", "content-type"])
        XCTAssertEqual(request.headers.map(\.value), ["application/json", "application/json"])
        XCTAssertEqual(request.body, body)
    }

    func testNomisJSONDecoder_whenDateStringHasFractionalSeconds_thenDecodesDate() throws {
        let payload = #"{"date":"2024-05-23T12:34:56.123000+0000"}"#
        let decoded = try NomisJSONDecoder().decode(NomisDateFixture.self, from: data(from: payload))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .nanosecond],
            from: decoded.date
        )

        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 5)
        XCTAssertEqual(components.day, 23)
        XCTAssertEqual(components.hour, 12)
        XCTAssertEqual(components.minute, 34)
        XCTAssertEqual(components.second, 56)
        XCTAssertEqual(components.nanosecond ?? 0, 123_000_000, accuracy: 1_000_000)
    }

    func testEthereumAddressAndHexHelpers_whenValuesAreProvided_thenNormalizeAndValidate() throws {
        var oddHex = "0xabc"
        oddHex.alignHexBytes()

        XCTAssertTrue("0x0abc".isHexWithPrefix())
        XCTAssertEqual(oddHex, "0x0abc")
        XCTAssertEqual("abc".stringAddHexPrefix(), "0xabc")
        XCTAssertEqual("0xabc".stringRemoveHexPrefix(), "abc")
        XCTAssertFalse("0xzz".isHex())

        let address = try XCTUnwrap(Address(ethereumAddress: "0x000000000000000000000000000000000000dead"))
        let sameAddress = try XCTUnwrap(Address(data: address.data))

        XCTAssertEqual(address.data.count, 20)
        XCTAssertEqual(address, sameAddress)
        XCTAssertNil(Address(ethereumAddress: "0x1234"))
    }

    func testABITypeParser_whenParsingAliasesAndArrays_thenBuildsExpectedParameterTypes() throws {
        XCTAssertEqual(try ABITypeParser.parseTypeString("uint"), .uint(bits: 256))
        XCTAssertEqual(try ABITypeParser.parseTypeString("int"), .int(bits: 256))
        XCTAssertEqual(try ABITypeParser.parseTypeString("bytes32"), .bytes(length: 32))
        XCTAssertEqual(
            try ABITypeParser.parseTypeString("uint256[]"),
            .array(type: .uint(bits: 256), length: 0)
        )
        XCTAssertEqual(
            try ABITypeParser.parseTypeString("address[2]"),
            .array(type: .address, length: 2)
        )
        XCTAssertThrowsError(try ABITypeParser.parseTypeString("uint256[bad]"))
    }

    func testERC20TransferCollection_whenRequested_thenBuildsCanonicalFunction() throws {
        let transferMethod = try XCTUnwrap(ABI.ContractCollection.erc20.methods[.transfer])

        XCTAssertEqual(transferMethod.name, .transfer)
        XCTAssertEqual(
            transferMethod.in,
            [
                .init(name: ABI.ContractCollection.InParameters.to.rawValue, type: .address),
                .init(name: ABI.ContractCollection.InParameters.value.rawValue, type: .uint(bits: 256))
            ]
        )
        XCTAssertEqual(
            transferMethod.out,
            [.init(name: ABI.ContractCollection.OutParameters.success.rawValue, type: .bool)]
        )

        let function = ABI.Element.Function.erc20transfer

        XCTAssertEqual(function.name, "transfer")
        XCTAssertEqual(function.inputs, transferMethod.in)
        XCTAssertEqual(function.outputs, transferMethod.out)
        XCTAssertFalse(function.constant)
        XCTAssertFalse(function.payable)
        XCTAssertEqual(function.signature, "transfer(address,uint256)")
        XCTAssertEqual(function.methodString, "a9059cbb")
    }

    func testABIEncoderNumericConversions_whenValuesProvided_thenParseExpectedBigInts() {
        XCTAssertEqual(ABIEncoder.convertToBigUInt("42" as AnyObject), BigUInt(42))
        XCTAssertEqual(ABIEncoder.convertToBigUInt("0x2a" as AnyObject), BigUInt(42))
        XCTAssertEqual(ABIEncoder.convertToBigUInt(UInt8(7) as AnyObject), BigUInt(7))
        XCTAssertNil(ABIEncoder.convertToBigUInt(BigInt(-1) as AnyObject))

        XCTAssertEqual(ABIEncoder.convertToBigInt("-42" as AnyObject), BigInt(-42))
        XCTAssertEqual(ABIEncoder.convertToBigInt("0x2a" as AnyObject), BigInt(42))
        XCTAssertEqual(ABIEncoder.convertToBigInt(UInt16(9) as AnyObject), BigInt(9))
    }

    func testABIEncoderAndDecoder_whenEncodingStaticAndDynamicTypes_thenRoundTripValues() throws {
        let address = try XCTUnwrap(Address(address: "0x000000000000000000000000000000000000dEaD"))
        let dynamicBytes = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let types: [ABI.Element.ParameterType] = [
            .uint(bits: 256),
            .bool,
            .address,
            .string,
            .dynamicBytes
        ]

        let encoded = try XCTUnwrap(
            ABIEncoder.encode(
                types: types,
                values: [
                    BigUInt(42) as AnyObject,
                    true as AnyObject,
                    address as AnyObject,
                    "fearless" as AnyObject,
                    dynamicBytes as AnyObject
                ]
            )
        )
        let decoded = try XCTUnwrap(ABIDecoder.decode(types: types, data: encoded))

        XCTAssertEqual(encoded.count % 32, 0)
        XCTAssertEqual(decoded[0] as? BigUInt, BigUInt(42))
        XCTAssertEqual(decoded[1] as? Bool, true)
        XCTAssertEqual(decoded[2] as? Address, address)
        XCTAssertEqual(decoded[3] as? String, "fearless")
        XCTAssertEqual(decoded[4] as? Data, dynamicBytes)
    }

    func testABIEncoderAndDecoder_whenEncodingArrayAndTupleTypes_thenRoundTripValues() throws {
        let arrayType = try ABITypeParser.parseTypeString("uint256[]")
        let tupleType = ABI.Element.ParameterType.tuple(types: [.bool, .uint(bits: 256)])

        let encoded = try XCTUnwrap(
            ABIEncoder.encode(
                types: [arrayType, tupleType],
                values: [
                    [BigUInt(1), BigUInt(2), BigUInt(3)] as AnyObject,
                    [false as AnyObject, BigUInt(99) as AnyObject] as AnyObject
                ]
            )
        )
        let decoded = try XCTUnwrap(ABIDecoder.decode(types: [arrayType, tupleType], data: encoded))
        let decodedArray = try XCTUnwrap(decoded[0] as? [AnyObject])
        let decodedTuple = try XCTUnwrap(decoded[1] as? [AnyObject])

        XCTAssertEqual(decodedArray.compactMap { $0 as? BigUInt }, [BigUInt(1), BigUInt(2), BigUInt(3)])
        XCTAssertEqual(decodedTuple[0] as? Bool, false)
        XCTAssertEqual(decodedTuple[1] as? BigUInt, BigUInt(99))
    }

    func testTypedMessage_whenDecodedAndHashed_thenPreservesDomainTypesAndPayloadPrefix() throws {
        let json: [String: Any] = [
            "types": [
                "EIP712Domain": [
                    ["name": "name", "type": "string"],
                    ["name": "chainId", "type": "uint256"]
                ],
                "Person": [
                    ["name": "name", "type": "string"],
                    ["name": "wallet", "type": "address"]
                ],
                "Mail": [
                    ["name": "from", "type": "Person"],
                    ["name": "to", "type": "Person"],
                    ["name": "contents", "type": "string"]
                ]
            ],
            "primaryType": "Mail",
            "domain": [
                "name": "Fearless",
                "chainId": "42"
            ],
            "message": [
                "from": [
                    "name": "Alice",
                    "wallet": "0x0000000000000000000000000000000000000001"
                ],
                "to": [
                    "name": "Bob",
                    "wallet": "0x0000000000000000000000000000000000000002"
                ],
                "contents": "Hello"
            ]
        ]

        let message = try TypedMessage(json: json, version: .v4)
        let payload = try fearless.hash(message: message, version: .v4)

        XCTAssertEqual(message.primaryType, "Mail")
        XCTAssertEqual(message.domain.chainId, 42)
        XCTAssertEqual(message.types["Mail"]?.map(\.name), ["from", "to", "contents"])
        XCTAssertEqual(
            try encodedType(primaryType: "Mail", types: message.types),
            "Mail(Person from,Person to,string contents)Person(string name,address wallet)"
        )
        XCTAssertEqual(payload.count, 66)
        XCTAssertEqual(Array(payload.prefix(2)), [0x19, 0x01])
    }

    func testTypedMessage_whenInvalidJsonProvided_thenReportsInvalidData() {
        XCTAssertEqual(TypedMessageSignError.invalidVersion.messageError(), "Invalid version")
        XCTAssertEqual(TypedMessageSignError.invalidData.messageError(), "Invalid data")
        XCTAssertEqual(TypedMessageSignError.unknown("bad").messageError(), "bad")

        XCTAssertThrowsError(
            try TypedMessage(json: ["types": [:], "message": [:]], version: .v4)
        ) { error in
            XCTAssertEqual((error as? TypedMessageSignError)?.messageError(), "Invalid data")
        }
    }

    func testChainEcosystemFlags_whenQueried_thenIdentifyExpectedFamilies() {
        XCTAssertTrue(ChainEcosystem.kusama.isKusama)
        XCTAssertFalse(ChainEcosystem.polkadot.isKusama)

        XCTAssertTrue(ChainEcosystem.polkadot.isPolkadot)
        XCTAssertFalse(ChainEcosystem.substrate.isPolkadot)

        XCTAssertTrue(ChainEcosystem.ethereum.isEthereum)
        XCTAssertTrue(ChainEcosystem.ethereumBased.isEthereum)
        XCTAssertFalse(ChainEcosystem.ton.isEthereum)
    }

    func testLockTypeMetadata_whenQueried_thenProvidesExpectedOrderAndLocalizedTitles() {
        let locale = Locale(identifier: "en_US")

        XCTAssertEqual(LockType.democracy.rawValue, "democrac")
        XCTAssertEqual(LockType.locksOrder, [.vesting, .staking, .democracy])
        XCTAssertFalse(LockType.staking.displayType.value(for: locale).isEmpty)
        XCTAssertFalse(LockType.vesting.displayType.value(for: locale).isEmpty)
        XCTAssertFalse(LockType.democracy.displayType.value(for: locale).isEmpty)
    }

    func testLanguageSelectionInteractor_whenLoadedAndSelectionChanges_thenUpdatesPresenterAndManager() {
        let localizationManager = TestLocalizationManager(
            selectedLocalization: "en",
            availableLocalizations: ["en", "ja_JP", "pt-BR"]
        )
        let presenter = LanguageSelectionPresenterRecorder()
        let interactor = LanguageSelectionInteractor(localizationManager: localizationManager)
        interactor.presenter = presenter

        interactor.load()

        XCTAssertEqual(presenter.loadedLanguages.map { $0.map(\.code) }, [["en", "ja_JP", "pt-BR"]])
        XCTAssertEqual(presenter.selectedLanguageCodes, ["en"])

        XCTAssertTrue(interactor.select(language: Language(code: "ja_JP")))

        XCTAssertEqual(localizationManager.selectedLocalization, "ja_JP")
        XCTAssertEqual(presenter.selectedLanguageCodes, ["en", "ja_JP"])

        XCTAssertFalse(interactor.select(language: Language(code: "ja_JP")))
        XCTAssertEqual(presenter.selectedLanguageCodes, ["en", "ja_JP"])
    }

    func testExternalApiExplorerTypeActionTitle_whenKnownAndUnknownTypesProvided_thenReturnsExpectedTitleAvailability() {
        let locale = Locale(identifier: "en_US")
        let soraMetricsExtrinsicExplorer = ChainModel.ExternalApiExplorer(
            type: .subscan,
            types: [.extrinsic],
            url: "https://sorametrics.org/sorav2?tab=extrinsics&q={value}"
        )
        let soraMetricsAccountExplorer = ChainModel.ExternalApiExplorer(
            type: .subscan,
            types: [.account, .address],
            url: "https://sorametrics.org/sorav2?tab=balance&address={value}"
        )

        let knownTypes: [ChainModel.ExternalApiExplorerType] = [
            .subscan,
            .polkascan,
            .etherscan,
            .reef,
            .oklink
        ]

        XCTAssertTrue(knownTypes.allSatisfy { type in
            type.actionTitle().value(for: locale)?.isEmpty == false
        })
        XCTAssertEqual(ChainModel.ExternalApiExplorerType.unknown.actionTitle().value(for: locale), "")
        XCTAssertEqual(soraMetricsExtrinsicExplorer.displayName, "SoraMetrics")
        XCTAssertEqual(soraMetricsExtrinsicExplorer.actionTitle().value(for: locale), "SoraMetrics")
        XCTAssertTrue(soraMetricsExtrinsicExplorer.supportsTransactionLookup)
        XCTAssertFalse(soraMetricsExtrinsicExplorer.supportsAccountLookup)
        XCTAssertEqual(
            soraMetricsExtrinsicExplorer.explorerUrl(for: "0xabc", type: soraMetricsExtrinsicExplorer.transactionType)?
                .absoluteString,
            "https://sorametrics.org/sorav2?tab=extrinsics&q=0xabc"
        )
        XCTAssertFalse(soraMetricsAccountExplorer.supportsTransactionLookup)
        XCTAssertTrue(soraMetricsAccountExplorer.supportsAccountLookup)
        XCTAssertEqual(
            soraMetricsAccountExplorer.accountUrl(for: "cnVudGltZQ")?.absoluteString,
            "https://sorametrics.org/sorav2?tab=balance&address=cnVudGltZQ"
        )
        XCTAssertTrue(URL(string: "https://sorametrics.org/sorav2")?.isSoraMetricsExplorer == true)
    }

    func testSoraSubqueryPriceQueryFactory_whenPiIndexerRequested_thenBuildsPolkaswapIndexerShape() throws {
        let piQuery = SoraSubqueryPriceQueryFactory.queryString(
            priceIds: ["xor", "val"],
            cursor: "",
            url: try XCTUnwrap(URL(string: "https://pi.soramitsu.io/graphql"))
        )
        let cursorQuery = SoraSubqueryPriceQueryFactory.queryString(
            priceIds: ["xor"],
            cursor: "cursor-1",
            url: try XCTUnwrap(URL(string: "https://pi.soramitsu.io/graphql"))
        )
        let legacyQuery = SoraSubqueryPriceQueryFactory.queryString(
            priceIds: ["xor"],
            cursor: "cursor-1",
            url: try XCTUnwrap(URL(string: "https://legacy.example/graphql"))
        )

        XCTAssertTrue(piQuery.contains("entities: assets("))
        XCTAssertTrue(piQuery.contains("edges {"))
        XCTAssertTrue(piQuery.contains("node {"))
        XCTAssertTrue(piQuery.contains("priceUSD"))
        XCTAssertFalse(piQuery.contains("nodes {"))
        XCTAssertFalse(piQuery.contains("after:"))

        XCTAssertTrue(cursorQuery.contains(#"after: "cursor-1","#))
        XCTAssertTrue(legacyQuery.contains("nodes {"))
        XCTAssertFalse(legacyQuery.contains("edges {"))
    }

    func testLocalizedFilterModels_whenPreferredLanguagesProvided_thenUseExplicitLanguages() {
        let preferredLanguages = Locale(identifier: "en").rLanguages

        let assetSort = AssetNetworksSort(
            type: .name,
            selected: true,
            preferredLanguages: preferredLanguages
        )
        let nftFilter = NftCollectionFilter(
            type: .spam,
            selected: true,
            preferredLanguages: preferredLanguages
        )
        let historyFilter = WalletTransactionHistoryFilter(
            type: .reward,
            selected: true,
            preferredLanguages: preferredLanguages
        )

        XCTAssertEqual(
            assetSort.title,
            R.string.localizable.commonName(preferredLanguages: preferredLanguages)
        )
        XCTAssertEqual(
            nftFilter.title,
            R.string.localizable.nftsFiltersSpam(preferredLanguages: preferredLanguages)
        )
        XCTAssertEqual(
            historyFilter.title,
            R.string.localizable.walletFiltersRewardsAndSlashes(preferredLanguages: preferredLanguages)
        )
    }

    func testSoraSubsquidHistoryQueryFactory_whenPiIndexerRequested_thenBuildsPolkaswapIndexerShape() throws {
        let piQuery = SoraSubsquidHistoryQueryFactory.queryForAddress(
            "alice",
            count: 25,
            cursor: nil,
            url: try XCTUnwrap(URL(string: "https://pi.soramitsu.io/graphql")),
            filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)]
        )
        let cursorQuery = SoraSubsquidHistoryQueryFactory.queryForAddress(
            "alice",
            count: 25,
            cursor: "cursor-1",
            url: try XCTUnwrap(URL(string: "https://pi.soramitsu.io/graphql")),
            filters: WalletTransactionHistoryFilter.defaultFilters()
        )
        let legacyQuery = SoraSubsquidHistoryQueryFactory.queryForAddress(
            "alice",
            count: 25,
            cursor: nil,
            url: try XCTUnwrap(URL(string: "https://legacy.example/graphql")),
            filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)]
        )

        XCTAssertTrue(piQuery.contains("historyElementsConnection: historyElements"))
        XCTAssertTrue(piQuery.contains(#"{ address: "alice", method: {notIn: ["swap","rewarded"]} }"#))
        XCTAssertTrue(piQuery.contains(#"{ dataTo: "alice", method: {notIn: ["swap","rewarded"]} }"#))
        XCTAssertTrue(piQuery.contains("orderBy: TIMESTAMP_DESC"))
        XCTAssertTrue(piQuery.contains("execution"))
        XCTAssertFalse(piQuery.contains("method_not_in"))
        XCTAssertFalse(piQuery.contains("after:"))

        XCTAssertTrue(cursorQuery.contains(#"after: "cursor-1","#))
        XCTAssertFalse(cursorQuery.contains("notIn"))

        XCTAssertTrue(legacyQuery.contains("historyElementsConnection("))
        XCTAssertTrue(legacyQuery.contains("method_not_in"))
        XCTAssertTrue(legacyQuery.contains(#"after: "1""#))
        XCTAssertTrue(legacyQuery.contains("orderBy: timestamp_DESC"))
    }

    func testPriceDataHelper_whenAssetsHaveStoredPrices_thenReturnsUniquePricesForCurrency() throws {
        let currency = Currency.euro()
        let chain = makeChain(chainId: "sora")
        let xorAsset = pricedAsset(
            id: "xor",
            price: "1.23",
            fiatDayChange: "0.45",
            priceProvider: PriceProvider(type: .sorasubquery, id: "xor-price", precision: nil),
            coingeckoPriceId: "xor-gecko"
        )
        let duplicateXorAsset = pricedAsset(
            id: "xor-duplicate",
            price: "9.99",
            fiatDayChange: nil,
            priceProvider: PriceProvider(type: .sorasubquery, id: "xor-price", precision: nil),
            coingeckoPriceId: nil
        )
        let valAsset = pricedAsset(
            id: "val",
            price: "0.5",
            fiatDayChange: "-1.25",
            priceProvider: nil,
            coingeckoPriceId: "val-gecko"
        )
        let noPriceAsset = AssetModel(
            id: "empty",
            name: "No Price",
            symbol: "EMPTY",
            precision: 18,
            price: nil,
            isUtility: false,
            isNative: false,
            type: .normal,
            coingeckoPriceId: "empty-gecko"
        )

        let prices = PriceDataHelper.prices(
            for: currency,
            from: [
                ChainAsset(chain: chain, asset: xorAsset),
                ChainAsset(chain: chain, asset: duplicateXorAsset),
                ChainAsset(chain: chain, asset: valAsset),
                ChainAsset(chain: chain, asset: noPriceAsset)
            ]
        )

        XCTAssertEqual(prices.map(\.priceId), ["xor-price", "val-gecko"])
        XCTAssertEqual(prices.map(\.currencyId), ["eur", "eur"])

        let xorPrice = try XCTUnwrap(prices.first { $0.priceId == "xor-price" })
        XCTAssertEqual(xorPrice.price, "1.23")
        XCTAssertEqual(xorPrice.fiatDayChange, decimal("0.45"))
        XCTAssertEqual(xorPrice.coingeckoPriceId, "xor-gecko")

        let valPrice = try XCTUnwrap(prices.first { $0.priceId == "val-gecko" })
        XCTAssertEqual(valPrice.price, "0.5")
        XCTAssertEqual(valPrice.fiatDayChange, decimal("-1.25"))
        XCTAssertEqual(valPrice.coingeckoPriceId, "val-gecko")

        XCTAssertNil(noPriceAsset.getPrice(for: currency))
        XCTAssertNil(xorAsset.getPrice(for: "eur"))
    }

    func testSimpleHelperModels_whenInitialized_thenExposeExpectedValues() {
        let defaultAlignment = ContentAlignment()
        let customAlignment = ContentAlignment(vertical: .bottom, horizontal: .right)
        let status = SubscanStatusData<String>(
            code: 100,
            message: "Subscan failure",
            generatedAt: 1_700_000_000,
            data: nil
        )
        let error = SubscanError(statusData: status)

        if case .top = defaultAlignment.vertical {} else {
            XCTFail("Default vertical alignment should be top")
        }
        if case .left = defaultAlignment.horizontal {} else {
            XCTFail("Default horizontal alignment should be left")
        }
        if case .bottom = customAlignment.vertical {} else {
            XCTFail("Custom vertical alignment should be bottom")
        }
        if case .right = customAlignment.horizontal {} else {
            XCTFail("Custom horizontal alignment should be right")
        }

        XCTAssertFalse(status.isSuccess)
        XCTAssertEqual(error.code, 100)
        XCTAssertEqual(error.message, "Subscan failure")
        XCTAssertNoThrow(PrintTimer(name: "unit-test").done())
    }

    func testConvenienceErrors_whenConvertedToContent_thenExposeExpectedTitleAndMessage() {
        let convenienceError = ConvenienceError(error: "Plain error")
        let contentError = ConvenienceContentError(title: "Title", message: "Message")

        XCTAssertEqual(convenienceError.errorDescription, "Plain error")
        XCTAssertEqual(convenienceError.toErrorContent(for: nil).title, "Plain error")
        XCTAssertEqual(convenienceError.toErrorContent(for: nil).message, "")
        XCTAssertEqual(contentError.toErrorContent(for: nil).title, "Title")
        XCTAssertEqual(contentError.toErrorContent(for: nil).message, "Message")
    }

    func testCallbackClosureIfProvided_whenClosureMissing_thenDoesNothing() {
        XCTAssertNoThrow(
            callbackClosureIfProvided(
                nil as ((Result<Int, Error>) -> Void)?,
                queue: nil,
                result: .success(10)
            )
        )
    }

    func testCallbackClosureIfProvided_whenQueueMissing_thenCallsClosureImmediately() {
        var receivedValue: Int?

        callbackClosureIfProvided(
            { result in
                receivedValue = try? result.get()
            },
            queue: nil,
            result: .success(10)
        )

        XCTAssertEqual(receivedValue, 10)
    }

    func testCallbackClosureIfProvided_whenQueueProvided_thenDispatchesResult() {
        let expectation = expectation(description: "Callback dispatched")
        let queue = DispatchQueue(label: "jp.co.soramitsu.fearless.tests.callback")

        callbackClosureIfProvided(
            { result in
                XCTAssertEqual(try? result.get(), 11)
                expectation.fulfill()
            },
            queue: queue,
            result: .success(11)
        )

        wait(for: [expectation], timeout: 1)
    }

    func testAssetSelectionStakingType_whenQueried_thenExposesExpectedMetadata() {
        XCTAssertNil(AssetSelectionStakingType.normal(chainAsset: nil).title)
        XCTAssertNil(AssetSelectionStakingType.normal(chainAsset: nil).chainAsset)
        XCTAssertEqual(AssetSelectionStakingType.pool(chainAsset: nil).title, "POOL")
        XCTAssertNil(AssetSelectionStakingType.pool(chainAsset: nil).chainAsset)
    }

    func testAssetSelectionTableViewCellModel_whenInitialized_thenStoresProvidedValuesAndSelection() {
        let model = AssetSelectionTableViewCellModel(
            title: "SORA",
            subtitle: "Mainnet",
            icon: nil,
            isSelected: true,
            stakingType: .pool(chainAsset: nil)
        )

        XCTAssertEqual(model.title, "SORA")
        XCTAssertEqual(model.subtitle, "Mainnet")
        XCTAssertNil(model.icon)
        XCTAssertTrue(model.isSelected)
        XCTAssertEqual(model.stakingType, .pool(chainAsset: nil))
    }

    func testSelectableViewModelObserver_whenSelectionChanges_thenNotifiesUntilRemoved() {
        let model = AssetSelectionTableViewCellModel(
            title: "SORA",
            subtitle: nil,
            icon: nil,
            isSelected: false,
            stakingType: .normal(chainAsset: nil)
        )
        let observer = SelectionObserver()

        model.addObserver(observer)
        model.addObserver(observer)
        model.isSelected = true
        model.isSelected = true
        model.removeObserver(observer)
        model.isSelected = false

        XCTAssertEqual(observer.changeCount, 1)
    }

    func testPolkaswapLiquidityFilterMode_whenQueried_thenProvidesExpectedCodes() {
        XCTAssertEqual(PolkaswapLiquidityFilterMode.disabled.code, "Disabled")
        XCTAssertEqual(PolkaswapLiquidityFilterMode.forbidSelected.code, "ForbidSelected")
        XCTAssertEqual(PolkaswapLiquidityFilterMode.allowSelected.code, "AllowSelected")
    }

    func testLiquiditySourceType_whenQueried_thenProvidesExpectedMetadata() {
        let locale = Locale(identifier: "en_US")

        XCTAssertEqual(LiquiditySourceType.smart.name, "Smart")
        XCTAssertEqual(LiquiditySourceType.smart.code, [])
        XCTAssertEqual(LiquiditySourceType.smart.filterMode, .disabled)
        XCTAssertFalse(LiquiditySourceType.smart.description(for: locale).isEmpty)

        XCTAssertEqual(LiquiditySourceType.xyk.name, "xyk")
        XCTAssertEqual(LiquiditySourceType.xyk.code, [["XYKPool", nil]])
        XCTAssertEqual(LiquiditySourceType.xyk.filterMode, .allowSelected)
        XCTAssertFalse(LiquiditySourceType.xyk.description(for: locale).isEmpty)

        XCTAssertEqual(LiquiditySourceType.tbc.name, "tbc")
        XCTAssertEqual(LiquiditySourceType.tbc.code, [["MulticollateralBondingCurvePool", nil]])
        XCTAssertEqual(LiquiditySourceType.tbc.filterMode, .allowSelected)
        XCTAssertFalse(LiquiditySourceType.tbc.description(for: locale).isEmpty)
    }

    func testWalletTransactionType_whenQueried_thenExposesRequiredTypesAndComparesByBackendName() {
        let locale = Locale(identifier: "en_US")
        let incoming = WalletTransactionType.incoming
        let outgoing = WalletTransactionType.outgoing
        let sameBackend = WalletTransactionType(
            backendName: "INCOMING",
            displayName: LocalizableResource { _ in "Different" },
            isIncome: false,
            typeIcon: UIImage()
        )

        XCTAssertEqual(incoming.backendName, "INCOMING")
        XCTAssertTrue(incoming.isIncome)
        XCTAssertNil(incoming.typeIcon)
        XCTAssertFalse(incoming.displayName.value(for: locale).isEmpty)

        XCTAssertEqual(outgoing.backendName, "OUTGOING")
        XCTAssertFalse(outgoing.isIncome)
        XCTAssertNil(outgoing.typeIcon)
        XCTAssertFalse(outgoing.displayName.value(for: locale).isEmpty)

        XCTAssertEqual(WalletTransactionType.required.map(\.backendName), ["OUTGOING", "INCOMING"])
        XCTAssertEqual(incoming, sameBackend)
        XCTAssertEqual(sameBackend.displayName.value(for: locale), "Different")
        XCTAssertNotEqual(incoming, outgoing)
    }

    func testBoolIntValue_whenQueried_thenMapsToBinaryValues() {
        XCTAssertEqual(true.intValue, 1)
        XCTAssertEqual(false.intValue, 0)
    }

    func testAnyReducer_whenWrappingConcreteReducer_thenDelegatesReduction() {
        let reducer = AnyReducer(reducer: SumReducer())

        XCTAssertEqual(reducer.reduce(list: [1, 2, 3], initialValue: 10), 16)
    }

    func testTimeFormatter_whenSecondsContainMinutes_thenFormatsMinutesAndSeconds() {
        XCTAssertEqual(TimeFormatter.minutesSecondsString(from: 5), "00:05")
        XCTAssertEqual(TimeFormatter.minutesSecondsString(from: 65), "01:05")
        XCTAssertEqual(TimeFormatter.minutesSecondsString(from: 3665), "01:05")
    }

    func testAccessoryViewModel_whenInitializedWithDefaultsAndOverrides_thenStoresValues() {
        let defaultModel = AccessoryViewModel(title: "Title", action: "Open")
        let icon = UIImage()
        let customModel = AccessoryViewModel(
            title: "Custom",
            action: "Close",
            icon: icon,
            numberOfLines: 2,
            shouldAllowAction: false
        )

        XCTAssertEqual(defaultModel.title, "Title")
        XCTAssertEqual(defaultModel.action, "Open")
        XCTAssertNil(defaultModel.icon)
        XCTAssertEqual(defaultModel.numberOfLines, 1)
        XCTAssertTrue(defaultModel.shouldAllowAction)

        XCTAssertEqual(customModel.title, "Custom")
        XCTAssertEqual(customModel.action, "Close")
        XCTAssertNotNil(customModel.icon)
        XCTAssertEqual(customModel.numberOfLines, 2)
        XCTAssertFalse(customModel.shouldAllowAction)
    }

    func testChainOptionsViewModel_whenCompared_thenUsesTextOnly() {
        let first = ChainOptionsViewModel(text: "Polkadot", icon: nil)
        let matching = ChainOptionsViewModel(text: "Polkadot", icon: BundleImageViewModel(image: UIImage()))
        let different = ChainOptionsViewModel(text: "Kusama", icon: nil)

        XCTAssertEqual(first, matching)
        XCTAssertNotEqual(first, different)
    }

    func testJsonExportAction_whenLocalized_thenProvidesTitles() {
        let locale = Locale(identifier: "en_US")

        XCTAssertFalse(JsonExportAction.file.localizableTitle(for: locale).isEmpty)
        XCTAssertFalse(JsonExportAction.text.localizableTitle(for: locale).isEmpty)
    }

    func testReplaceChainOption_whenQueried_thenProvidesCasesAndTitles() {
        let locale = Locale(identifier: "en_US")

        XCTAssertEqual(ReplaceChainOption.allCases.count, 2)
        guard case .create = ReplaceChainOption.allCases[0] else {
            XCTFail("Expected create option first")
            return
        }
        guard case .import = ReplaceChainOption.allCases[1] else {
            XCTFail("Expected import option second")
            return
        }
        XCTAssertFalse(ReplaceChainOption.create.localizableTitle(for: locale).isEmpty)
        XCTAssertFalse(ReplaceChainOption.import.localizableTitle(for: locale).isEmpty)
        _ = ReplaceChainOption.create.icon
        _ = ReplaceChainOption.import.icon
    }

    func testWalletHistoryRequest_whenInitialized_thenStoresAssetsAndEncodes() throws {
        let request = WalletHistoryRequest(assets: ["xor", "val"])
        let encoded = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(WalletHistoryRequest.self, from: encoded)

        XCTAssertEqual(request.assets, ["xor", "val"])
        XCTAssertNil(request.filter)
        XCTAssertNil(request.fromDate)
        XCTAssertNil(request.toDate)
        XCTAssertNil(request.type)
        XCTAssertEqual(decoded, request)
    }

    func testAccountCreateChainType_whenQueried_thenReportsIncludedFamilies() {
        XCTAssertTrue(AccountCreateChainType.substrate.includeSubstrate)
        XCTAssertFalse(AccountCreateChainType.substrate.includeEthereum)

        XCTAssertFalse(AccountCreateChainType.ethereum.includeSubstrate)
        XCTAssertTrue(AccountCreateChainType.ethereum.includeEthereum)

        XCTAssertTrue(AccountCreateChainType.both.includeSubstrate)
        XCTAssertTrue(AccountCreateChainType.both.includeEthereum)
    }

    func testBundleImageViewModel_whenLoadingAndCanceling_thenUpdatesImageView() {
        let image = UIImage()
        let imageView = UIImageView()
        let viewModel = BundleImageViewModel(image: image)

        viewModel.loadImage(on: imageView, targetSize: .zero, animated: false, cornerRadius: 0)
        XCTAssertNotNil(imageView.image)

        imageView.image = nil
        viewModel.loadImage(
            on: imageView,
            targetSize: .zero,
            animated: false,
            cornerRadius: 0,
            completionHandler: nil
        )
        XCTAssertNotNil(imageView.image)

        imageView.image = nil
        viewModel.loadImage(on: imageView, targetSize: .zero, animated: false)
        XCTAssertNotNil(imageView.image)

        imageView.image = nil
        viewModel.loadImage(on: imageView, placholder: nil, targetSize: .zero, animated: false)
        XCTAssertNotNil(imageView.image)

        viewModel.cancel(on: imageView)
        XCTAssertNil(imageView.image)
    }

    func testRemoteImageViewModelFactory_whenUsingDefaultImplementation_thenBuildsModelWithURL() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/icon.png"))
        let factory = TestRemoteImageFactory()

        XCTAssertEqual(factory.buildRemoteImageViewModel(url: url).url, url)
    }

    func testMultiSelectNetworksViewModelFactory_whenFilteringAndSelecting_thenBuildsStableRows() throws {
        let polkadotIcon = try XCTUnwrap(URL(string: "https://example.com/polkadot.svg"))
        let kusamaIcon = try XCTUnwrap(URL(string: "https://example.com/kusama.svg"))
        let polkadot = makeChain(chainId: "dot", name: "Polkadot", icon: polkadotIcon)
        let kusama = makeChain(chainId: "ksm", name: "Kusama", icon: kusamaIcon)
        let factory = MultiSelectNetworksViewModelFactoryImpl()
        let locale = Locale(identifier: "en_US")

        let filtered = factory.buildViewModel(
            dataSource: [polkadot, kusama],
            selectedChains: ["ksm"],
            searchText: "SA",
            locale: locale
        )

        XCTAssertEqual(filtered.selectedCountTitle, "Selected: 1")
        XCTAssertTrue(filtered.allIsSelected)
        XCTAssertEqual(filtered.cells.count, 1)
        XCTAssertEqual(filtered.cells.first?.chainId, "ksm")
        XCTAssertEqual(filtered.cells.first?.chainName, "Kusama")
        XCTAssertEqual(filtered.cells.first?.icon?.url, kusamaIcon)
        XCTAssertEqual(filtered.cells.first?.isSelected, true)

        let unfiltered = factory.buildViewModel(
            dataSource: [polkadot, kusama],
            selectedChains: ["dot"],
            searchText: nil,
            locale: locale
        )

        XCTAssertEqual(unfiltered.selectedCountTitle, "Selected: 1")
        XCTAssertFalse(unfiltered.allIsSelected)
        XCTAssertEqual(unfiltered.cells.map(\.chainId), ["dot", "ksm"])
        XCTAssertEqual(unfiltered.cells.map(\.isSelected), [true, false])

        let toggledKusama = try XCTUnwrap(unfiltered.cells.last?.toggle())
        let replaced = unfiltered.replace(cells: [toggledKusama])

        XCTAssertEqual(replaced.selectedCountTitle, unfiltered.selectedCountTitle)
        XCTAssertEqual(replaced.cells, [toggledKusama])
        XCTAssertEqual(toggledKusama.chainId, "ksm")
        XCTAssertTrue(toggledKusama.isSelected)

        let noneSelected = factory.buildViewModel(
            dataSource: [polkadot],
            selectedChains: nil,
            searchText: "",
            locale: locale
        )

        XCTAssertEqual(noneSelected.selectedCountTitle, "Selected: 0")
        XCTAssertFalse(noneSelected.allIsSelected)
        XCTAssertEqual(noneSelected.cells.first?.isSelected, false)
    }

    func testSettingsMigrator_whenMigratingAcrossVersions_thenStagesAndFinalizesChanges() throws {
        let settings = InMemorySettingsManager()
        settings.set(value: "legacy", for: "existing")
        settings.set(value: "remove-me", for: "removed")

        let migrator = SettingsMigrator(
            sourceVersion: .version1,
            destinationVersion: .version3,
            settings: settings
        )

        XCTAssertEqual(migrator.currentVersion, .version1)

        try migrator.switchVersion()

        XCTAssertEqual(migrator.currentVersion, .version2)
        XCTAssertEqual(migrator.value(for: "existing") as? String, "legacy")

        migrator.set(value: "staged", for: "existing")
        migrator.set(value: 42, for: "new")
        migrator.remove(key: "removed")

        XCTAssertEqual(settings.string(for: "existing"), "legacy")
        XCTAssertEqual(settings.string(for: "removed"), "remove-me")
        XCTAssertEqual(migrator.keysToRemoveOnFinalize, ["removed"])

        XCTAssertThrowsError(try migrator.finalize()) { error in
            guard case KeystoreMigratingError.destinationNotReached = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        try migrator.switchVersion()

        XCTAssertEqual(migrator.currentVersion, .version3)
        XCTAssertEqual(migrator.value(for: "existing") as? String, "staged")
        XCTAssertEqual(migrator.value(for: "new") as? Int, 42)

        try migrator.finalize()

        XCTAssertEqual(settings.string(for: "existing"), "staged")
        XCTAssertEqual(settings.integer(for: "new"), 42)
        XCTAssertNil(settings.string(for: "removed"))
    }

    func testSettingsMigrator_whenCurrentVersionHasNoNextVersion_thenThrows() {
        let migrator = SettingsMigrator(
            sourceVersion: .version12,
            destinationVersion: .version12,
            settings: InMemorySettingsManager()
        )

        XCTAssertThrowsError(try migrator.switchVersion()) { error in
            guard case KeystoreMigratingError.nextVersionMissing = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testAccountStatisticsResponse_whenDecoded_thenMapsNestedOptionalStats() throws {
        let json = """
        {
          "data": {
            "score": 42.5,
            "address": "sora-address",
            "stats": {
              "nativeBalanceUSD": 10.5,
              "holdTokensBalanceUSD": 7.25,
              "walletAge": 12,
              "totalTransactions": 34,
              "totalRejectedTransactions": 2,
              "averageTransactionTime": 1.5,
              "maxTransactionTime": 9.5,
              "minTransactionTime": 0.5,
              "scoredAt": null
            }
          }
        }
        """
        let response = try JSONDecoder().decode(AccountStatisticsResponse.self, from: Data(json.utf8))
        let stats = try XCTUnwrap(response.data?.stats)

        XCTAssertEqual(response.data?.score, Decimal(string: "42.5"))
        XCTAssertEqual(response.data?.address, "sora-address")
        XCTAssertEqual(stats.nativeBalanceUSD, Decimal(string: "10.5"))
        XCTAssertEqual(stats.holdTokensBalanceUSD, Decimal(string: "7.25"))
        XCTAssertEqual(stats.walletAge, 12)
        XCTAssertEqual(stats.totalTransactions, 34)
        XCTAssertEqual(stats.totalRejectedTransactions, 2)
        XCTAssertEqual(stats.averageTransactionTime, Decimal(string: "1.5"))
        XCTAssertEqual(stats.maxTransactionTime, Decimal(string: "9.5"))
        XCTAssertEqual(stats.minTransactionTime, Decimal(string: "0.5"))
        XCTAssertNil(stats.scoredAt)
    }

    func testDecimalDoubleValue_whenQueried_thenBridgesThroughNSDecimalNumber() {
        XCTAssertEqual(Decimal(string: "42.25")?.doubleValue, 42.25)
    }

    func testArrayDiff_whenCompared_thenReturnsSymmetricDifference() {
        let diff = [1, 2, 3].diff(from: [3, 4])

        XCTAssertEqual(Set(diff), [1, 2, 4])
    }

    func testCollectionAverageHelpers_whenValuesProvided_thenReturnExpectedAverages() {
        XCTAssertEqual([1, 2, 3].sum(), 6)
        XCTAssertEqual([1, 2, 4].average() as Int, 2)
        XCTAssertEqual([1, 2].average() as Double, 1.5)
        XCTAssertEqual([Double]().average(), 0)
        XCTAssertEqual([1.0, 2.0, 3.0].average(), 2.0)
    }

    func testPagination_whenEncodedAndDecoded_thenPreservesCountAndContext() throws {
        let pagination = Pagination(count: 25, context: ["cursor": "abc"])
        let encoded = try JSONEncoder().encode(pagination)
        let decoded = try JSONDecoder().decode(Pagination.self, from: encoded)

        XCTAssertEqual(decoded, pagination)
    }

    func testFieldStatusIcon_whenQueried_thenReturnsOnlyForNonEmptyStates() {
        XCTAssertNil(FieldStatus.none.icon)
        XCTAssertNotNil(FieldStatus.valid.icon)
        XCTAssertNotNil(FieldStatus.warning.icon)
        XCTAssertNotNil(FieldStatus.invalid.icon)
    }

    func testSimpleCodableModels_whenRoundTripped_thenPreserveIdentifiers() throws {
        let contact = Contact(name: "Alice", address: "sora-address", chainId: "sora-main")
        let amount = AmountDecimal(value: try XCTUnwrap(Decimal(string: "12.3")))
        let receiveInfo = ReceiveInfo(
            accountId: "account",
            assetId: "asset",
            amount: amount,
            details: "details"
        )
        let phishingItem = PhishingItem(source: "source", publicKey: "public-key")

        let decodedContact = try JSONDecoder().decode(Contact.self, from: JSONEncoder().encode(contact))
        let decodedReceiveInfo = try JSONDecoder().decode(ReceiveInfo.self, from: JSONEncoder().encode(receiveInfo))
        let decodedPhishingItem = try JSONDecoder().decode(PhishingItem.self, from: JSONEncoder().encode(phishingItem))

        XCTAssertEqual(decodedContact, contact)
        XCTAssertEqual(decodedContact.identifier, "sora-address")
        XCTAssertEqual(decodedReceiveInfo, receiveInfo)
        XCTAssertEqual(decodedPhishingItem.identifier, "public-key")
        XCTAssertEqual(decodedPhishingItem.source, "source")
    }

    func testPrimitiveAmountAndRuntimeModels_whenUsed_thenExposeExpectedValues() throws {
        let wrapper = PrimitiveContextWrapper(value: ["xor", "val"])
        let absoluteAmount = AmountInputResult.absolute(Decimal(12))
        let positiveRateAmount = AmountInputResult.rate(Decimal(string: "0.25")!)
        let negativeRateAmount = AmountInputResult.rate(Decimal(string: "-0.25")!)
        let runtimeInfo = RuntimeDispatchInfo(feeValue: BigUInt(42))
        let runtimePayload = """
        {
            "inclusionFee": {
                "baseFee": "0x0a",
                "lenFee": "0x05",
                "adjustedWeightFee": "0x01"
            }
        }
        """
        let invalidRuntimePayload = """
        {
            "inclusionFee": {
                "baseFee": "not-hex",
                "lenFee": "0x02",
                "adjustedWeightFee": "0xzz"
            }
        }
        """

        let decodedRuntimeInfo = try JSONDecoder().decode(
            RuntimeDispatchInfo.self,
            from: data(from: runtimePayload)
        )
        let invalidRuntimeInfo = try JSONDecoder().decode(
            RuntimeDispatchInfo.self,
            from: data(from: invalidRuntimePayload)
        )

        XCTAssertEqual(wrapper.value, ["xor", "val"])
        XCTAssertEqual(absoluteAmount.absoluteValue(from: 100), 12)
        XCTAssertEqual(positiveRateAmount.absoluteValue(from: 100), 25)
        XCTAssertEqual(negativeRateAmount.absoluteValue(from: 100), 0)
        XCTAssertEqual(runtimeInfo.fee, "42")
        XCTAssertEqual(decodedRuntimeInfo.fee, "16")
        XCTAssertEqual(invalidRuntimeInfo.fee, "2")
    }

    func testLanguageAndCryptoTypeHelpers_whenLocaleProvided_thenReturnLocalizedMetadata() {
        let locale = Locale(identifier: "en_US")
        let englishUS = Language(code: "en_US")
        let unknownLanguage = Language(code: "unknown")

        XCTAssertEqual(englishUS.title(in: locale), "English")
        XCTAssertEqual(englishUS.region(in: locale), "United States")
        XCTAssertNil(unknownLanguage.region(in: locale))

        XCTAssertEqual(CryptoType.sr25519.titleForLocale(locale), "Schnorrkel")
        XCTAssertEqual(CryptoType.ed25519.titleForLocale(locale), "Edwards")
        XCTAssertEqual(CryptoType.ecdsa.titleForLocale(locale), "ECDSA")
        XCTAssertEqual(CryptoType.sr25519.subtitleForLocale(locale), "sr25519 (recommended)")
        XCTAssertEqual(CryptoType.ed25519.subtitleForLocale(locale), "ed25519 (alternative)")
        XCTAssertEqual(CryptoType.ecdsa.subtitleForLocale(locale), "(BTC/ETH compatible)")
        XCTAssertFalse(CryptoType.sr25519.supportsSeedFromSecretKey)
        XCTAssertTrue(CryptoType.ed25519.supportsSeedFromSecretKey)
        XCTAssertTrue(CryptoType.ecdsa.supportsSeedFromSecretKey)
    }

    func testRewardDestination_whenBuiltFromPayee_thenMapsToExpectedDestination() throws {
        let stashItem = StashItem(stash: "stash-address", controller: "controller-address")
        let chainFormat = ChainFormat.substrate(42)
        let payoutAddress = "payout-address"
        let restake = try RewardDestination<AccountAddress>(
            payee: .staked,
            stashItem: stashItem,
            chainFormat: chainFormat
        )
        let stash = try RewardDestination<AccountAddress>(
            payee: .stash,
            stashItem: stashItem,
            chainFormat: chainFormat
        )
        let controller = try RewardDestination<AccountAddress>(
            payee: .controller,
            stashItem: stashItem,
            chainFormat: chainFormat
        )
        let payout = try RewardDestination<AccountAddress>(
            payee: .address(payoutAddress),
            stashItem: stashItem,
            chainFormat: chainFormat
        )
        let account = fearless.ChainAccountResponse(
            chainId: "chain",
            accountId: Data(repeating: 1, count: 32),
            publicKey: Data(repeating: 2, count: 32),
            name: "Account",
            cryptoType: .sr25519,
            addressPrefix: 42,
            isEthereumBased: false,
            isChainAccount: true,
            walletId: "wallet"
        )
        let accountDestination = RewardDestination<fearless.ChainAccountResponse>.payout(account: account)

        XCTAssertEqual(restake, .restake)
        XCTAssertEqual(stashItem.identifier, "stash-address")
        XCTAssertEqual(stash, .payout(account: "stash-address"))
        XCTAssertEqual(controller, .payout(account: "controller-address"))
        XCTAssertEqual(payout, .payout(account: payoutAddress))
        XCTAssertNil(RewardDestination<fearless.ChainAccountResponse>.restake.payoutAccount)
        XCTAssertEqual(accountDestination.payoutAccount, account)
        XCTAssertNotEqual(accountDestination.accountAddress, .restake)
    }

    func testWalletConnectMetadataAndChainModels_whenBuilt_thenExposeExpectedIdentifiers() throws {
        let metadata = AppMetadata.createFearlessMetadata()
        let substrateCaip2 = try XCTUnwrap(Caip2ChainId(raw: "polkadot:91b171bb"))
        let ethereumCaip2 = Caip2ChainId(namespace: "eip155", reference: "1")
        let substrateBlockchain = try XCTUnwrap(Blockchain("polkadot:91b171bb"))
        let ethereumBlockchain = try XCTUnwrap(Blockchain("eip155:1"))
        let substrateChain = makeChain(chainId: "91b171bb")
        let ethereumChain = makeChain(chainId: "0x1")
        let resolution = WalletConnectChainsResolution(
            requiredChains: ChainsResolution(
                allowed: [
                    BlockChain(blockchain: substrateBlockchain, chain: substrateChain)
                ],
                forbidden: []
            ),
            optionalChains: ChainsResolution(
                allowed: [
                    BlockChain(blockchain: ethereumBlockchain, chain: ethereumChain)
                ],
                forbidden: Set([ethereumBlockchain])
            )
        )

        XCTAssertEqual(metadata.name, "Fearless wallet")
        XCTAssertEqual(metadata.description, "Defi wallet")
        XCTAssertEqual(metadata.url, "https://fearlesswallet.io")
        XCTAssertEqual(
            metadata.icons,
            ["https://raw.githubusercontent.com/soramitsu/shared-features-utils/master/icons/FW%20icon%20128.png"]
        )
        XCTAssertEqual(metadata.redirect?.native, "fearless://")
        XCTAssertNil(metadata.redirect?.universal)

        XCTAssertEqual(substrateCaip2.namespace, "polkadot")
        XCTAssertEqual(substrateCaip2.reference, "91b171bb")
        XCTAssertEqual(substrateCaip2.raw, "polkadot:91b171bb")
        XCTAssertEqual(ethereumCaip2.raw, "eip155:1")
        XCTAssertNil(Caip2ChainId(raw: "polkadot"))
        XCTAssertNil(Caip2ChainId(raw: "too:many:parts"))
        XCTAssertEqual(
            resolution.allBlockChains().map { $0.blockchain.absoluteString },
            ["polkadot:91b171bb", "eip155:1"]
        )
        XCTAssertEqual(resolution.optionalChains.forbidden, Set([ethereumBlockchain]))
    }

    func testTonNFT_whenMetadataImageMissingAndPreviewListShort_thenUsesAvailablePreview() throws {
        let previewURL = "https://example.com/nft-100.png"
        let nftItem = makeTonNFTItem(
            previews: [
                .init(resolution: "100x100", url: previewURL)
            ]
        )

        let nft = try TonNFT(nftItem: nftItem)

        XCTAssertEqual(nft.imageURL, URL(string: previewURL))
        XCTAssertEqual(nft.preview.size100, URL(string: previewURL))
    }

    private func makeTonNFTItem(
        previews: [Components.Schemas.ImagePreview]?
    ) -> Components.Schemas.NftItem {
        Components.Schemas.NftItem(
            address: "0:2cf55953e92efbeadab7ba725c3f93a0b23f842cbba72d7b8e6f510a70e422e3",
            index: 0,
            verified: true,
            metadata: .init(),
            previews: previews,
            approved_by: []
        )
    }

    func testWalletDetailsModels_whenBuilt_thenExposeFlowWalletAndInactiveState() {
        let wallet = AccountGenerator.generateMetaAccount()
        let account = AccountGenerator.generateChainAccount()
        let exportInfo = ChainAccountInfo(
            chain: makeChain(chainId: account.chainId),
            account: ChainAccountResponse(
                chainId: account.chainId,
                accountId: account.accountId,
                publicKey: account.publicKey,
                name: wallet.name,
                cryptoType: .sr25519,
                addressPrefix: 42,
                isEthereumBased: false,
                isChainAccount: true,
                walletId: wallet.metaId
            )
        )
        let normalFlow = WalletDetailsFlow.normal(wallet: wallet)
        let exportFlow = WalletDetailsFlow.export(wallet: wallet, accounts: [exportInfo])
        let viewModel = WalletDetailsCellViewModel(
            chainImageViewModel: nil,
            account: exportInfo.account,
            chain: exportInfo.chain,
            address: "address",
            accountMissing: true,
            actionsAvailable: normalFlow.actionsAvailable,
            locale: Locale(identifier: "en_US"),
            chainUnused: true
        )

        XCTAssertTrue(normalFlow.actionsAvailable)
        XCTAssertFalse(exportFlow.actionsAvailable)
        XCTAssertEqual(normalFlow.wallet.metaId, wallet.metaId)
        XCTAssertEqual(exportFlow.wallet.metaId, wallet.metaId)
        XCTAssertEqual(viewModel.account?.chainId, account.chainId)
        XCTAssertEqual(viewModel.address, "address")
        XCTAssertTrue(viewModel.chainUnused)
        XCTAssertTrue(viewModel.cellInactive)
    }

    func testRPCRequestsAndWalletConnectExtrinsic_whenEncoded_thenUseExpectedWireFormats() throws {
        let pagedKeysWithoutOffset = try XCTUnwrap(
            jsonFragment(from: PagedKeysRequest(key: "0xabc", count: 2)) as? [Any]
        )
        let pagedKeysWithOffset = try XCTUnwrap(
            jsonFragment(from: PagedKeysRequest(key: "0xabc", count: 2, offset: "0xdef")) as? [Any]
        )
        let storageQueryWithoutBlock = try XCTUnwrap(
            jsonFragment(from: StorageQuery(keys: [Data([0x01, 0x02])], blockHash: nil)) as? [Any]
        )
        let storageQueryWithBlock = try XCTUnwrap(
            jsonFragment(from: StorageQuery(keys: [Data([0x01])], blockHash: Data([0xFF]))) as? [Any]
        )
        let rawCall = WalletConnectPolkadotCall.raw(bytes: Data([0xAB, 0xCD]))
        let rawCallJson = try XCTUnwrap(jsonFragment(from: rawCall) as? String)
        let extrinsic = WalletConnectExtrinsic(
            address: "5Address",
            blockHash: "0xblock",
            blockNumber: BigUInt(10),
            era: .immortal,
            genesisHash: "0xgenesis",
            method: rawCall,
            nonce: BigUInt(7),
            specVersion: 1,
            tip: BigUInt(0),
            transactionVersion: 2,
            signedExtensions: ["CheckNonce"],
            version: 4
        )
        let extrinsicJson = try jsonObject(from: extrinsic)

        XCTAssertEqual(pagedKeysWithoutOffset.count, 2)
        XCTAssertEqual(pagedKeysWithoutOffset[0] as? String, "0xabc")
        XCTAssertEqual(pagedKeysWithoutOffset[1] as? Int, 2)
        XCTAssertEqual(pagedKeysWithOffset[2] as? String, "0xdef")

        XCTAssertEqual(storageQueryWithoutBlock.count, 1)
        XCTAssertEqual(storageQueryWithoutBlock.first as? [String], ["0x0102"])
        XCTAssertEqual(storageQueryWithBlock.first as? [String], ["0x01"])
        XCTAssertEqual(storageQueryWithBlock[1] as? String, "0xff")

        XCTAssertEqual(rawCallJson, "0xabcd")
        XCTAssertEqual(extrinsicJson["address"] as? String, "5Address")
        XCTAssertEqual(extrinsicJson["blockHash"] as? String, "0xblock")
        XCTAssertEqual(extrinsicJson["blockNumber"] as? String, "10")
        let eraJson = try XCTUnwrap(extrinsicJson["era"] as? [Any])
        XCTAssertEqual(eraJson.first as? Int, 0)
        XCTAssertEqual(extrinsicJson["method"] as? String, "0xabcd")
        XCTAssertEqual(extrinsicJson["nonce"] as? String, "7")
        XCTAssertEqual(extrinsicJson["signedExtensions"] as? [String], ["CheckNonce"])
        XCTAssertEqual(extrinsicJson["version"] as? Int, 4)
    }

    func testErrorContentAndRewardJsonModels_whenQueried_thenReturnExpectedValues() throws {
        let locale = Locale(identifier: "en_US")
        let json = JSON.dictionaryValue([
            "id": .stringValue("event-1"),
            "timestamp": .stringValue("1700000000"),
            "address": .stringValue("stash"),
            "reward": .dictionaryValue([
                "validator": .stringValue("validator"),
                "isReward": .boolValue(true),
                "era": .unsignedIntValue(12),
                "amount": .stringValue("123456")
            ])
        ])
        let invalidJson = JSON.dictionaryValue([
            "id": .stringValue("event-1")
        ])
        let reward = try XCTUnwrap(SubqueryRewardItemData(from: json))
        let userRejectedContent = JSONRPCError.userRejected.toErrorContent(for: locale)
        let commonContents = [
            CommonError.undefined.toErrorContent(for: locale),
            CommonError.network.toErrorContent(for: locale),
            CommonError.internal.toErrorContent(for: locale)
        ]
        let accountCreateContents = [
            AccountCreateError.invalidMnemonicSize.toErrorContent(for: locale),
            AccountCreateError.invalidMnemonicFormat.toErrorContent(for: locale),
            AccountCreateError.invalidSeed.toErrorContent(for: locale),
            AccountCreateError.invalidKeystore.toErrorContent(for: locale),
            AccountCreateError.unsupportedNetwork.toErrorContent(for: locale),
            AccountCreateError.duplicated.toErrorContent(for: locale)
        ]
        let selector = ViewSelectorAction(title: "Open", selector: NSSelectorFromString("open"))

        XCTAssertEqual(reward.eventId, "event-1")
        XCTAssertEqual(reward.timestamp, 1_700_000_000)
        XCTAssertEqual(reward.validatorAddress, "validator")
        XCTAssertEqual(reward.era, EraIndex(12))
        XCTAssertEqual(reward.stashAddress, "stash")
        XCTAssertEqual(reward.amount, BigUInt(123_456))
        XCTAssertTrue(reward.isReward)
        XCTAssertNil(SubqueryRewardItemData(from: invalidJson))

        XCTAssertEqual(userRejectedContent.title, "4001")
        XCTAssertEqual(userRejectedContent.message, "User rejected request")
        (commonContents + accountCreateContents).forEach { content in
            XCTAssertFalse(content.title.isEmpty)
            XCTAssertFalse(content.message.isEmpty)
        }
        XCTAssertEqual(selector.title, "Open")
        XCTAssertNotNil(selector.selector)
    }

    func testAssetAndChainHelpers_whenQueried_thenExposeDisplayInfoStorageAndIdentifiers() throws {
        let chainIcon = try XCTUnwrap(URL(string: "https://example.com/chain.svg"))
        let assetIcon = try XCTUnwrap(URL(string: "https://example.com/asset.svg"))
        let normalAsset = AssetModel(
            id: "xor",
            name: "XOR",
            symbol: "xor",
            precision: 18,
            icon: assetIcon,
            isUtility: true,
            isNative: true,
            type: .normal
        )
        let xcmAsset = AssetModel(
            id: "xcm",
            name: "Cross DOT",
            symbol: "xcDOT",
            precision: 10,
            icon: nil,
            currencyId: "xcm-id",
            isUtility: false,
            isNative: false,
            type: .xcm
        )
        let assetsAsset = AssetModel(
            id: "assets",
            name: "Assets Pallet",
            symbol: "asst",
            precision: 12,
            icon: nil,
            currencyId: "1984",
            isUtility: false,
            isNative: false,
            type: .assets
        )
        let soraAsset = AssetModel(
            id: "sora",
            name: "Sora Asset",
            symbol: "xor",
            precision: 18,
            icon: nil,
            currencyId: "sora-id",
            isUtility: true,
            isNative: false,
            type: .soraAsset
        )
        let bokoloAsset = AssetModel(
            id: "bokolo",
            name: "Bokolo Cash",
            symbol: "BKC",
            precision: 18,
            icon: nil,
            currencyId: BokoloConstants.bokoloCashAssetCurrencyId,
            isUtility: false,
            isNative: false,
            type: .soraAsset
        )
        let chain = makeChain(
            chainId: "chain",
            assets: Set([normalAsset, xcmAsset, assetsAsset, soraAsset, bokoloAsset]),
            icon: chainIcon
        )

        let normalChainAsset = ChainAsset(chain: chain, asset: normalAsset)
        let xcmChainAsset = ChainAsset(chain: chain, asset: xcmAsset)
        let assetsChainAsset = ChainAsset(chain: chain, asset: assetsAsset)
        let soraChainAsset = ChainAsset(chain: chain, asset: soraAsset)
        let bokoloChainAsset = ChainAsset(chain: chain, asset: bokoloAsset)

        XCTAssertEqual(normalAsset.displayInfo.displayPrecision, 5)
        XCTAssertEqual(normalAsset.displayInfo.assetPrecision, 18)
        XCTAssertEqual(normalAsset.displayInfo.symbol, "XOR")
        XCTAssertEqual(normalAsset.displayInfo.icon, assetIcon)
        XCTAssertEqual(normalAsset.displayInfo(with: chainIcon).icon, assetIcon)
        XCTAssertEqual(xcmAsset.displayInfo(with: chainIcon).icon, chainIcon)
        XCTAssertEqual(normalAsset.normalizedSymbol(), "xor")
        XCTAssertEqual(xcmAsset.normalizedSymbol(), "DOT")

        XCTAssertEqual(normalChainAsset.identifier, "chain : xor")
        XCTAssertEqual(normalChainAsset.assetDisplayInfo.symbol, "XOR")
        XCTAssertEqual(normalChainAsset.storagePath, .account)
        XCTAssertEqual(xcmChainAsset.storagePath, .tokens)
        XCTAssertEqual(assetsChainAsset.storagePath, .assetsAccount)
        XCTAssertEqual(soraChainAsset.storagePath, .account)
        XCTAssertTrue(bokoloChainAsset.isBokolo)
        XCTAssertFalse(normalChainAsset.isBokolo)
    }

    func testPrimitiveModelHelpers_whenQueried_thenReturnExpectedValues() throws {
        let chainSettings = ChainSettings.defaultSettings(for: "chain-id")
        var mutedSettings = chainSettings
        mutedSettings.setIssueMuted(true)
        let metadata = fearless.RuntimeMetadataItem(
            chain: "chain-id",
            version: 12,
            txVersion: 3,
            metadata: Data([0x01, 0x02, 0x03])
        )
        let fee = AssetTransactionFee(
            identifier: "fee-id",
            assetId: "asset-id",
            amount: AmountDecimal(value: 42),
            context: ["call": "transfer"]
        )
        let locksWithClaimable = StakingLocks(
            staked: Decimal(1),
            unstaking: Decimal(2),
            redeemable: Decimal(3),
            claimable: Decimal(4)
        )
        let locksWithoutClaimable = StakingLocks(
            staked: Decimal(1),
            unstaking: Decimal(2),
            redeemable: Decimal(3),
            claimable: nil
        )
        let remoteSettings = PolkaswapRemoteSettings(
            version: "v1",
            availableDexIds: [
                PolkaswapDex(name: "Polkaswap", code: 0, assetId: "xor")
            ],
            availableSources: [.smart, .xyk],
            forceSmartIds: ["xor"],
            xstusdId: "xstusd"
        )
        let source = TextSharingSource(message: "hello", subject: "subject")
        let activityViewController = UIActivityViewController(
            activityItems: [source],
            applicationActivities: nil
        )

        XCTAssertEqual(fearless.KeystoreTag.secretKeyTagForAddress("addr"), "addr-secretKey")
        XCTAssertEqual(fearless.KeystoreTag.entropyTagForAddress("addr"), "addr-entropy")
        XCTAssertEqual(fearless.KeystoreTag.deriviationTagForAddress("addr"), "addr-deriv")
        XCTAssertEqual(fearless.KeystoreTag.seedTagForAddress("addr"), "addr-seed")
        XCTAssertEqual(
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId("meta", accountId: Data([0x0A])),
            "meta0a-substrateSecretKey"
        )
        XCTAssertEqual(fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId("meta"), "meta-ethereumSecretKey")
        XCTAssertEqual(fearless.KeystoreTagV2.entropyTagForMetaId("meta"), "meta-entropy")
        XCTAssertEqual(fearless.KeystoreTagV2.substrateDerivationTagForMetaId("meta"), "meta-substrateDeriv")
        XCTAssertEqual(fearless.KeystoreTagV2.ethereumDerivationTagForMetaId("meta"), "meta-ethereumDeriv")
        XCTAssertEqual(fearless.KeystoreTagV2.substrateSeedTagForMetaId("meta"), "meta-substrateSeed")
        XCTAssertEqual(fearless.KeystoreTagV2.ethereumSeedTagForMetaId("meta"), "meta-ethereumSeed")

        XCTAssertEqual(chainSettings.identifier, "chain-id")
        XCTAssertTrue(chainSettings.autobalanced)
        XCTAssertFalse(chainSettings.issueMuted)
        XCTAssertTrue(mutedSettings.issueMuted)
        XCTAssertEqual(try JSONDecoder().decode(fearless.RuntimeMetadataItem.self, from: JSONEncoder().encode(metadata)), metadata)
        XCTAssertEqual(metadata.identifier, "chain-id")
        XCTAssertEqual(try JSONDecoder().decode(AssetTransactionFee.self, from: JSONEncoder().encode(fee)), fee)
        XCTAssertEqual(locksWithClaimable.total, Decimal(10))
        XCTAssertEqual(locksWithoutClaimable.total, Decimal(6))
        XCTAssertEqual(remoteSettings.identifier, "v1")
        XCTAssertEqual(try JSONDecoder().decode(PolkaswapRemoteSettings.self, from: JSONEncoder().encode(remoteSettings)).identifier, "v1")

        XCTAssertEqual(source.activityViewControllerPlaceholderItem(activityViewController) as? String, "hello")
        XCTAssertEqual(
            source.activityViewController(activityViewController, itemForActivityType: nil) as? String,
            "hello"
        )
        XCTAssertEqual(
            source.activityViewController(activityViewController, subjectForActivityType: nil),
            "subject"
        )
        XCTAssertEqual(
            TextSharingSource(message: "hello").activityViewController(
                activityViewController,
                subjectForActivityType: nil
            ),
            "(No subject)"
        )
    }

    func testChainAction_whenQueried_thenProvidesLocalizedTitlesAndIcons() throws {
        let locale = Locale(identifier: "en_US")
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        let actions: [ChainAction] = [
            .copyAddress,
            .polkascan(url: url),
            .subscan(url: url),
            .etherscan(url: url),
            .oklink(url: url),
            .switchNode,
            .export,
            .replace,
            .reefscan(url: url),
            .claimCrowdloanRewards
        ]

        actions.forEach { action in
            XCTAssertFalse(action.localizableTitle(for: locale).isEmpty)
            _ = action.icon
        }

        let soraMetricsUrl = try XCTUnwrap(URL(string: "https://sorametrics.org/sorav2?tab=extrinsics&q=0xabc"))
        XCTAssertEqual(ChainAction.subscan(url: soraMetricsUrl).localizableTitle(for: locale), "SoraMetrics")
    }

    func testScamInfo_whenQueried_thenMapsTypesCaseInsensitivelyAndProvidesDescriptions() {
        let locale = Locale(identifier: "en_US")
        let scamInfo = ScamInfo(name: "Bad", address: "addr", type: .scam, subtype: "subtype")

        XCTAssertEqual(scamInfo.identifier, "addr")
        XCTAssertEqual(ScamInfo.ScamType(from: "SCAM"), .scam)
        XCTAssertEqual(ScamInfo.ScamType(from: " Low network activity "), .lowScore)
        XCTAssertNil(ScamInfo.ScamType(from: "not-a-type"))
        XCTAssertTrue(ScamInfo.ScamType.scam.isScam)
        XCTAssertFalse(ScamInfo.ScamType.exchange.isScam)
        XCTAssertNil(ScamInfo.ScamType.unknown.description(for: locale, assetName: "XOR"))

        let describedTypes: [ScamInfo.ScamType] = [.scam, .donation, .exchange, .sanctions, .lowScore]
        XCTAssertTrue(describedTypes.allSatisfy { type in
            type.description(for: locale, assetName: "XOR")?.isEmpty == false
        })
    }

    func testGraphQLResponse_whenDataPayloadProvided_thenDecodesDataCase() throws {
        let json = #"{"data":{"value":7}}"#

        let response = try JSONDecoder().decode(
            GraphQLResponse<GraphQLFixture>.self,
            from: Data(json.utf8)
        )

        guard case let .data(fixture) = response else {
            XCTFail("Expected data response")
            return
        }
        XCTAssertEqual(fixture, GraphQLFixture(value: 7))
    }

    func testGraphQLResponse_whenErrorsProvided_thenDecodesFirstError() throws {
        let json = #"{"errors":[{"message":"first"},{"message":"second"}]}"#

        let response = try JSONDecoder().decode(
            GraphQLResponse<GraphQLFixture>.self,
            from: Data(json.utf8)
        )

        guard case let .errors(error) = response else {
            XCTFail("Expected error response")
            return
        }
        XCTAssertEqual(error.message, "first")
    }

    func testGraphQLResponse_whenPayloadMissingDataAndErrors_thenThrows() {
        let json = #"{"extensions":{"requestId":"abc"}}"#

        XCTAssertThrowsError(
            try JSONDecoder().decode(GraphQLResponse<GraphQLFixture>.self, from: Data(json.utf8))
        )
    }

    func testBlockExplorerResponseModels_whenDecoded_thenExposeProtocolViews() throws {
        let collatorJson = """
        {
          "collatorRounds": {
            "nodes": [
              { "collatorId": "collator-a", "apr": 12.5 },
              { "collatorId": "collator-b", "apr": 7.25 }
            ]
          }
        }
        """
        let historyJson = """
        {
          "historyElements": [
            {
              "id": "event-1",
              "type": 3,
              "timestamp": "1700000000",
              "blockNumber": 42,
              "amount": "123456789"
            }
          ]
        }
        """

        let collators = try JSONDecoder().decode(
            SubqueryCollatorAprResponse.self,
            from: Data(collatorJson.utf8)
        )
        let history = try JSONDecoder().decode(
            SubsquidDelegatorHistoryData.self,
            from: Data(historyJson.utf8)
        )
        let historyItems = history.history(for: "ignored-address")

        XCTAssertEqual(collators.collatorAprInfos.count, 2)
        XCTAssertEqual(collators.collatorAprInfos[0].collatorId, "collator-a")
        XCTAssertEqual(collators.collatorAprInfos[0].apr, 12.5)
        XCTAssertEqual(historyItems.count, 1)
        XCTAssertEqual(historyItems[0].type, .delegate)
        XCTAssertEqual(historyItems[0].blockNumber, 42)
        XCTAssertEqual(historyItems[0].amount, BigUInt(123_456_789))
    }

    func testReferralMethodType_whenRawValueUnknown_thenFallsBackToBond() {
        XCTAssertEqual(ReferralMethodType(fromRawValue: "reserve"), .bond)
        XCTAssertEqual(ReferralMethodType(fromRawValue: "unreserve"), .unbond)
        XCTAssertEqual(ReferralMethodType(fromRawValue: "setReferrer"), .setReferrer)
        XCTAssertEqual(ReferralMethodType(fromRawValue: "not-known"), .bond)
    }

    func testAnyCodingKey_whenConstructedFromDifferentSources_thenPreservesValues() {
        let wrapped = AnyCodingKey(TestCodingKey.value)
        let stringKey = AnyCodingKey(stringValue: "account")
        let intKey = AnyCodingKey(intValue: 9)
        let explicitKey = AnyCodingKey(stringValue: "index", intValue: 2)

        XCTAssertEqual(wrapped.stringValue, "value")
        XCTAssertNil(wrapped.intValue)
        XCTAssertEqual(stringKey.stringValue, "account")
        XCTAssertNil(stringKey.intValue)
        XCTAssertEqual(intKey.stringValue, "9")
        XCTAssertEqual(intKey.intValue, 9)
        XCTAssertEqual(explicitKey.stringValue, "index")
        XCTAssertEqual(explicitKey.intValue, 2)
    }

    func testURLHelpers_whenGivenHandles_thenBuildExpectedPublicURLs() {
        XCTAssertEqual(
            URL.twitterAddress(for: "fearlesswallet")?.absoluteString,
            "https://twitter.com/fearlesswallet"
        )
        XCTAssertEqual(
            URL.riotAddress(for: "@fearless:matrix.org")?.absoluteString,
            "https://matrix.to/#/@fearless:matrix.org"
        )
    }

    func testAdaptersAndMappings_whenCalled_thenDelegateToUnderlyingTypes() {
        let mapper = AnyMapper(mapper: StringLengthMapper())
        let quantity = BigUInt(255).toEthereumQuantity()

        XCTAssertEqual(mapper.map(input: "sora"), 4)
        XCTAssertEqual(quantity.quantity, BigUInt(255))
        XCTAssertEqual(quantity.hex(), "0xff")
        XCTAssertEqual(TransactionHistoryItem.Status.success.walletValue, .commited)
        XCTAssertEqual(TransactionHistoryItem.Status.failed.walletValue, .rejected)
        XCTAssertEqual(TransactionHistoryItem.Status.pending.walletValue, .pending)
    }

    func testSimpleModelIdentifiersAndConfig_whenDecoded_thenExposeExpectedValues() throws {
        let excludedVersionsKey = "ex\u{0441}luded_versions"
        let appSupportData = try JSONSerialization.data(withJSONObject: [
            "min_supported_version": "2.0.0",
            excludedVersionsKey: ["1.0.0", "1.1.0"]
        ])
        let appSupportConfig = try JSONDecoder().decode(AppSupportConfig.self, from: appSupportData)
        let chainNode = ChainNodeModel(
            url: URL(string: "wss://node.example")!,
            name: "node",
            apikey: ChainNodeModel.ApiKey(queryName: "apiKey", keyName: "key")
        )
        let contactPayload = """
        {"peerAddress":"peer","peerName":"Alice","targetAddress":"target","updatedAt":42}
        """
        let contact = try JSONDecoder().decode(ContactItem.self, from: data(from: contactPayload))
        let historyItem = TransactionHistoryItem(
            sender: "sender",
            receiver: "receiver",
            status: .success,
            txHash: "0xhash",
            timestamp: 1_700_000_000,
            fee: "0.1",
            blockNumber: 12,
            txIndex: 2,
            callPath: .transfer,
            call: Data([0x01, 0x02])
        )
        let decodedHistoryItem = try JSONDecoder().decode(
            TransactionHistoryItem.self,
            from: JSONEncoder().encode(historyItem)
        )
        let transaction = AssetTransactionData(
            transactionId: "transaction-id",
            status: .commited,
            assetId: "xor",
            peerId: "peer",
            peerFirstName: "Alice",
            peerLastName: "Wallet",
            peerName: "Alice Wallet",
            details: "details",
            amount: AmountDecimal(value: 123.45),
            fees: [
                AssetTransactionFee(
                    identifier: "fee-id",
                    assetId: "xor",
                    amount: AmountDecimal(value: 0.1),
                    context: ["module": "balances"]
                )
            ],
            timestamp: 1_700_000_001,
            type: "transfer",
            reason: "reason",
            context: ["tx": "0xhash"]
        )
        let page = AssetTransactionPageData(transactions: [transaction])
        let decodedPage = try JSONDecoder().decode(
            AssetTransactionPageData.self,
            from: JSONEncoder().encode(page)
        )
        let metaAccount = makeMetaAccount(
            ethereumPublicKey: nil,
            chainAccounts: [
                ChainAccountModel(
                    chainId: "ethereum-chain",
                    accountId: Data(repeating: 0x01, count: 20),
                    publicKey: Data(repeating: 0x02, count: 33),
                    cryptoType: CryptoType.ecdsa.rawValue,
                    ethereumBased: true
                )
            ]
        )
        let managedAccount = ManagedMetaAccountModel(
            info: metaAccount,
            isSelected: true,
            order: 3,
            balance: "10 XOR"
        )
        let reorderedAccount = managedAccount.replacingOrder(9)
        let iconSize = CGSize(width: 1, height: 1)

        UIGraphicsBeginImageContextWithOptions(iconSize, false, 1)
        defer { UIGraphicsEndImageContext() }
        let context = try XCTUnwrap(UIGraphicsGetCurrentContext())

        EmptyAccountIcon().drawInContext(context, fillColor: .red, size: iconSize)

        XCTAssertEqual(appSupportConfig.minSupportedVersion, "2.0.0")
        XCTAssertEqual(appSupportConfig.excludedVersions, ["1.0.0", "1.1.0"])
        XCTAssertEqual(chainNode.identifier, "wss://node.example")
        XCTAssertEqual(contact.identifier, "targetpeer")
        XCTAssertEqual(contact.peerName, "Alice")
        XCTAssertEqual(historyItem.identifier, "0xhash")
        XCTAssertEqual(decodedHistoryItem.identifier, "0xhash")
        XCTAssertEqual(decodedHistoryItem.callPath, .transfer)
        XCTAssertEqual(decodedPage, page)
        XCTAssertTrue(metaAccount.supportEthereum)
        XCTAssertEqual(managedAccount.identifier, "meta-id")
        XCTAssertEqual(reorderedAccount.order, 9)
        XCTAssertTrue(reorderedAccount.isSelected)
        XCTAssertEqual(reorderedAccount.info, metaAccount)
    }

    func testBalanceLocks_whenDecodedAndSorted_thenSplitKnownAndAuxiliaryLocks() throws {
        let locks: BalanceLocks = try [
            balanceLockPayload(displayId: "custom-low", amount: 1),
            balanceLockPayload(displayId: LockType.democracy.rawValue, amount: 3),
            balanceLockPayload(displayId: LockType.staking.rawValue, amount: 2),
            balanceLockPayload(displayId: "custom-high", amount: 9),
            balanceLockPayload(displayId: LockType.vesting.rawValue, amount: 4)
        ].map { payload in
            try JSONDecoder().decode(BalanceLock.self, from: data(from: payload))
        }

        XCTAssertEqual(locks.vesting()?.displayId, LockType.vesting.rawValue)
        XCTAssertNil(BalanceLocks([]).vesting())
        XCTAssertEqual(
            locks.mainLocks().compactMap(\.displayId),
            [
                LockType.vesting.rawValue,
                LockType.staking.rawValue,
                LockType.democracy.rawValue
            ]
        )
        XCTAssertEqual(locks.auxLocks().compactMap(\.displayId), ["custom-high", "custom-low"])
        XCTAssertEqual(locks.auxLocks().map(\.amount), [BigUInt(9), BigUInt(1)])
    }

    func testArrayDivide_whenPredicateMatchesSubset_thenPreservesOriginalOrderInBothBuckets() {
        let result = [1, 2, 3, 4, 5].divide { $0.isMultiple(of: 2) }

        XCTAssertEqual(result.slice, [2, 4])
        XCTAssertEqual(result.remainder, [1, 3, 5])
    }

    func testBigUIntHexHelpers_whenValuesAreValidAndInvalid_thenParseAndFormatExpectedHex() {
        XCTAssertNil(BigUInt.fromHexString(nil))
        XCTAssertNil(BigUInt.fromHexString("not-hex"))
        XCTAssertEqual(BigUInt.fromHexString("0x0f"), BigUInt(15))
        XCTAssertEqual(BigUInt.fromHexString("ff"), BigUInt(255))
        XCTAssertEqual(BigUInt(16).toHexString(), "0x10")
    }

    func testWalletConnectEthereumTransaction_whenDecoded_thenMapsHexFieldsAndWeb3Transaction() throws {
        let from = "0x0000000000000000000000000000000000000001"
        let to = "0x0000000000000000000000000000000000000002"
        let payload = """
        {
          "from": "\(from)",
          "to": "\(to)",
          "data": "0x1234",
          "gasLimit": "0x5208",
          "gasPrice": "0x3b9aca00",
          "value": "0xde0b6b3a7640000",
          "nonce": "0x0f"
        }
        """

        let transaction = try JSONDecoder().decode(
            WalletConnectEthereumTransaction.self,
            from: data(from: payload)
        )
        let decodedAgain = try JSONDecoder().decode(
            WalletConnectEthereumTransaction.self,
            from: JSONEncoder().encode(transaction)
        )
        let web3Transaction = try transaction.mapToWeb3()

        XCTAssertEqual(transaction.from, from)
        XCTAssertEqual(transaction.to, to)
        XCTAssertEqual(transaction.data, "0x1234")
        XCTAssertEqual(transaction.gasLimit, BigUInt(21000))
        XCTAssertEqual(transaction.gasPrice, BigUInt(1_000_000_000))
        XCTAssertEqual(transaction.value, BigUInt("1000000000000000000"))
        XCTAssertEqual(transaction.nonce, BigUInt(15))
        XCTAssertEqual(decodedAgain.nonce, BigUInt(15))
        XCTAssertEqual(web3Transaction.from?.hex(eip55: false), from)
        XCTAssertEqual(web3Transaction.to?.hex(eip55: false), to)
        XCTAssertEqual(web3Transaction.data.hex(), "0x1234")
        XCTAssertEqual(web3Transaction.gasLimit?.quantity, BigUInt(21000))
        XCTAssertEqual(web3Transaction.gasPrice?.quantity, BigUInt(1_000_000_000))
        XCTAssertEqual(web3Transaction.maxFeePerGas?.quantity, BigUInt(1_000_000_000))
        XCTAssertEqual(web3Transaction.maxPriorityFeePerGas?.quantity, BigUInt(1_000_000_000))
        XCTAssertEqual(web3Transaction.value?.quantity, BigUInt("1000000000000000000"))
        XCTAssertEqual(web3Transaction.transactionType, .legacy)
    }

    func testWalletConnectEthereumTransaction_whenOptionalOrInvalidFieldsDecoded_thenMapsToNilAndEmptyData() throws {
        let payload = """
        {
          "from": null,
          "to": null,
          "data": "not-hex",
          "gasLimit": "not-hex",
          "gasPrice": null,
          "value": null,
          "nonce": null
        }
        """

        let transaction = try JSONDecoder().decode(
            WalletConnectEthereumTransaction.self,
            from: data(from: payload)
        )
        let web3Transaction = try transaction.mapToWeb3()

        XCTAssertNil(transaction.from)
        XCTAssertNil(transaction.to)
        XCTAssertNil(transaction.gasLimit)
        XCTAssertNil(transaction.gasPrice)
        XCTAssertNil(transaction.value)
        XCTAssertNil(transaction.nonce)
        XCTAssertNil(web3Transaction.from)
        XCTAssertNil(web3Transaction.to)
        XCTAssertEqual(web3Transaction.data.hex(), "0x")
    }

    func testSubstrateDisplayStrings_whenSnakeAndCamelCaseProvided_thenCreateReadableLabels() {
        XCTAssertEqual("balances_transfer_keep_alive".replacingSnakeCase(), "balances transfer keep alive")
        XCTAssertEqual("balancesTransferKeepAlive".replacingCamelCase(), "balances Transfer Keep Alive")
        XCTAssertEqual("balancesTransferKeepAlive".displayCall, "Balances Transfer Keep Alive")
        XCTAssertEqual("staking_rewards".displayModule, "Staking Rewards")
    }

    func testChainHistoryRange_whenHistoryDepthExceedsCurrentEra_thenClampsStartAndActiveEra() {
        let range = ChainHistoryRange(currentEra: 2, activeEra: 0, historyDepth: 10)

        XCTAssertEqual(range.eraRange.start, 0)
        XCTAssertEqual(range.eraRange.end, 0)
        XCTAssertEqual(range.eraList, [0])
    }

    func testChainHistoryRange_whenRangeIsAvailable_thenBuildsInclusiveEraList() {
        let range = ChainHistoryRange(currentEra: 7, activeEra: 10, historyDepth: 2)

        XCTAssertEqual(range.eraRange.start, 5)
        XCTAssertEqual(range.eraRange.end, 9)
        XCTAssertEqual(range.eraList, [5, 6, 7, 8, 9])
    }

    func testDataProviderChanges_whenReduced_thenReturnLastNonDeletedValue() {
        let changesWithLastValue: [DataProviderChange<Int>] = [
            .delete(deletedIdentifier: "old"),
            .insert(newItem: 4),
            .update(newItem: 5)
        ]
        let changesWithDeleteLast: [DataProviderChange<Int>] = [
            .insert(newItem: 4),
            .update(newItem: 5),
            .delete(deletedIdentifier: "deleted")
        ]

        XCTAssertEqual(changesWithLastValue.reduceToLastChange(), 5)
        XCTAssertNil(changesWithDeleteLast.reduceToLastChange())
    }

    func testDataProviderChanges_whenSearchingFirstMatchingChange_thenIgnoresDeletesAndReturnsFirstMatch() {
        let changes: [DataProviderChange<Int>] = [
            .delete(deletedIdentifier: "old"),
            .insert(newItem: 1),
            .update(newItem: 3),
            .insert(newItem: 5)
        ]

        XCTAssertEqual(changes.firstToLastChange { $0 > 2 }, 3)
        XCTAssertNil(changes.firstToLastChange { $0 > 10 })
    }

    func testNoneStateOptional_whenAccessingValue_thenReturnsWrappedValueOrNil() {
        let emptyValue: NoneStateOptional<String> = .none
        let wrappedValue: NoneStateOptional<String> = .value("xor")

        XCTAssertNil(emptyValue.value)
        XCTAssertEqual(wrappedValue.value, "xor")
    }

    func testNumbersAndSlashesProcessor_whenTextContainsMixedCharacters_thenKeepsOnlyDigitsAndSlashes() {
        let processor = NumbersAndSlashesProcessor()

        XCTAssertEqual(processor.process(text: "ab 12/34-56.x"), "12/3456")
        XCTAssertEqual(processor.process(text: "no digits"), "")
    }

    func testFeeViewModel_whenInitialized_thenStoresDisplayState() {
        let viewModel = FeeViewModel(
            title: "Network fee",
            details: "0.01 XOR",
            isLoading: false,
            allowsEditing: true
        )

        XCTAssertEqual(viewModel.title, "Network fee")
        XCTAssertEqual(viewModel.details, "0.01 XOR")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(viewModel.allowsEditing)
    }

    func testTokenLock_whenIdIsUtf8_thenTrimsDisplayIdAndExposesLockType() throws {
        let lock = TokenLock(
            id: try XCTUnwrap("  staking  ".data(using: .utf8)),
            amount: BigUInt(123)
        )
        let binaryLock = TokenLock(id: Data([0xFF, 0xFE]), amount: BigUInt(1))

        XCTAssertEqual(lock.displayId, "staking")
        XCTAssertEqual(lock.lockType, "staking")
        XCTAssertNil(binaryLock.displayId)
    }

    func testMultiAddressQuery_whenAddressIsAccountId_thenReturnsAccountIdOnlyForMatchingCase() {
        let accountId = Data([1, 2, 3, 4])

        XCTAssertEqual(MultiAddress.accoundId(accountId).accountId, accountId)
        XCTAssertNil(MultiAddress.raw(accountId).accountId)
    }

    func testMultiSignature_whenBuiltFromCryptoType_thenPreservesSignatureKindAndData() {
        let signatureData = Data([1, 2, 3])

        assertSignature(
            MultiSignature.signature(from: .sr25519, data: signatureData),
            matches: .sr25519,
            data: signatureData
        )
        assertSignature(
            MultiSignature.signature(from: .ed25519, data: signatureData),
            matches: .ed25519,
            data: signatureData
        )
        assertSignature(
            MultiSignature.signature(from: .ecdsa, data: signatureData),
            matches: .ecdsa,
            data: signatureData
        )
    }

    func testRuntimeCall_whenCreatedFromCallCodingPath_thenCopiesModuleAndCallNames() {
        let call = RuntimeCall(callCodingPath: .transferKeepAlive, args: ["target": "alice"])

        XCTAssertEqual(call.moduleName, "Balances")
        XCTAssertEqual(call.callName, "transfer_keep_alive")
        XCTAssertEqual(call.args["target"], "alice")
    }

    func testChainModelNomisSupport_whenKnownEvmChainIdsProvided_thenMatchesSupportedList() {
        XCTAssertTrue(makeChain(chainId: "1").isNomisSupported)
        XCTAssertTrue(makeChain(chainId: "56").isNomisSupported)
        XCTAssertTrue(makeChain(chainId: "137").isNomisSupported)
        XCTAssertFalse(makeChain(chainId: "7e4e32d0feafd4f9c9414b0be86373f9a1efa904809b683453a9af6856d38ad5").isNomisSupported)
    }

    func testAccountIdVariant_whenChainIsReef_thenBuildsAddressVariant() throws {
        let accountId = Data(repeating: 1, count: 32)
        let reefChain = makeChain(
            chainId: "7834781d38e4798d548e34ec947d19deea29df148a7bf32484b7b24dacf8d4b7",
            addressPrefix: 1
        )
        let genericChain = makeChain(chainId: "generic", addressPrefix: 42)

        let reefVariant = try AccountIdVariant.build(raw: accountId, chain: reefChain)
        let genericVariant = try AccountIdVariant.build(raw: accountId, chain: genericChain)

        if case let .address(address) = reefVariant {
            XCTAssertFalse(address.isEmpty)
        } else {
            XCTFail("Expected Reef account id to be converted to address")
        }

        if case let .accountId(rawAccountId) = genericVariant {
            XCTAssertEqual(rawAccountId, accountId)
        } else {
            XCTFail("Expected generic account id to remain raw")
        }
    }

    func testStakingPool_whenDecodedAndRenamed_thenPreservesPoolInfo() throws {
        let depositor = Data([1, 2, 3])
        let root = Data([4, 5, 6])
        let payload = """
        {
          "id": "12",
          "name": "Main pool",
          "info": {
            "points": "12345",
            "state": ["Open"],
            "memberCounter": "7",
            "roles": {
              "depositor": "\(depositor.base64EncodedString())",
              "root": "\(root.base64EncodedString())"
            }
          }
        }
        """
        let data = try XCTUnwrap(payload.data(using: .utf8))

        let pool = try JSONDecoder().decode(StakingPool.self, from: data)
        let renamed = pool.byReplacingName("Renamed pool")

        XCTAssertEqual(pool.id, "12")
        XCTAssertEqual(pool.name, "Main pool")
        XCTAssertEqual(pool.info.points, BigUInt(12345))
        XCTAssertEqual(pool.info.state, .open)
        XCTAssertEqual(pool.info.memberCounter, 7)
        XCTAssertEqual(pool.info.roles.depositor, depositor)
        XCTAssertEqual(pool.info.roles.root, root)
        XCTAssertEqual(renamed.id, pool.id)
        XCTAssertEqual(renamed.info.points, pool.info.points)
        XCTAssertEqual(renamed.info.state, pool.info.state)
        XCTAssertEqual(renamed.info.memberCounter, pool.info.memberCounter)
        XCTAssertEqual(renamed.info.roles, pool.info.roles)
        XCTAssertEqual(renamed.name, "Renamed pool")
    }

    func testParachainLeaseModels_whenDecodedAndMapped_thenExposeLeaseValuesByParaId() throws {
        let fundAccountId = Data([1, 2, 3, 4])
        let slotPayload = """
        ["\(fundAccountId.base64EncodedString())", "123456"]
        """
        let slotData = try XCTUnwrap(slotPayload.data(using: .utf8))
        let slotLease = try JSONDecoder().decode(ParachainSlotLease.self, from: slotData)
        let leaseInfos: ParachainLeaseInfoList = [
            ParachainLeaseInfo(paraId: 100, fundAccountId: fundAccountId, leasedAmount: BigUInt(1)),
            ParachainLeaseInfo(paraId: 200, fundAccountId: Data([9]), leasedAmount: nil),
            ParachainLeaseInfo(paraId: 100, fundAccountId: Data([8]), leasedAmount: BigUInt(2))
        ]
        let leaseMap = leaseInfos.toMap()

        XCTAssertEqual(slotLease.accountId, fundAccountId)
        XCTAssertEqual(slotLease.amount, BigUInt(123_456))
        XCTAssertEqual(leaseMap[100]?.fundAccountId, Data([8]))
        XCTAssertEqual(leaseMap[100]?.leasedAmount, BigUInt(2))
        XCTAssertNil(leaseMap[200]?.leasedAmount)
    }

    func testParachainStakingModels_whenDecoded_thenExposeStatusesActionsAndCandidateInfo() throws {
        let owner = Data(repeating: 0x01, count: 32)
        let delegator = Data(repeating: 0x02, count: 32)
        let candidatePayload = """
        {"owner":"\(owner.base64EncodedString())","amount":"123.45"}
        """
        let metadataPayload = """
        {
          "bond": "1000",
          "delegationCount": "2",
          "totalCounted": "900",
          "lowestTopDelegationAmount": "10",
          "highestBottomDelegationAmount": "20",
          "lowestBottomDelegationAmount": "5",
          "topCapacity": ["Full"],
          "bottomCapacity": ["Partial"],
          "request": { "amount": "50", "whenExecutable": "16" },
          "status": ["Active"]
        }
        """
        let delegatorPayload = """
        {
          "id": "\(delegator.base64EncodedString())",
          "delegations": [
            { "owner": "\(owner.base64EncodedString())", "amount": "77" }
          ],
          "total": "100",
          "lessTotal": "25",
          "status": ["Leaving"]
        }
        """
        let revokePayload = """
        {"delegator":"\(delegator.base64EncodedString())","whenExecutable":"7","action":["revoke","12"]}
        """
        let decreasePayload = """
        {"delegator":"\(delegator.base64EncodedString())","whenExecutable":"8","action":["decrease","9"]}
        """

        let candidate = try JSONDecoder().decode(
            ParachainStakingCandidate.self,
            from: data(from: candidatePayload)
        )
        let metadata = try JSONDecoder().decode(
            ParachainStakingCandidateMetadata.self,
            from: data(from: metadataPayload)
        )
        let delegatorState = try JSONDecoder().decode(
            ParachainStakingDelegatorState.self,
            from: data(from: delegatorPayload)
        )
        let revokeRequest = try JSONDecoder().decode(
            ParachainStakingScheduledRequest.self,
            from: data(from: revokePayload)
        )
        let decreaseRequest = try JSONDecoder().decode(
            ParachainStakingScheduledRequest.self,
            from: data(from: decreasePayload)
        )
        let idleStatus = try JSONDecoder().decode(CollatorStatus.self, from: data(from: #"["Idle"]"#))
        let leavingStatus = try JSONDecoder().decode(CollatorStatus.self, from: data(from: #"["Leaving"]"#))
        let emptyCapacity = try JSONDecoder().decode(CapacityStatus.self, from: data(from: #"["Empty"]"#))
        let activeDelegatorStatus = try JSONDecoder().decode(DelegatorStatus.self, from: data(from: #"["Active"]"#))
        let aprInfo = SubqueryCollatorAprInfo(collatorId: "collator-address", apr: 12.5)
        let candidateInfo = ParachainStakingCandidateInfo(
            address: "collator-address",
            owner: owner,
            amount: AmountDecimal(value: 123.45),
            metadata: metadata,
            identity: AccountIdentity(name: "Collator"),
            subqueryData: aprInfo
        )
        let matchingCandidateInfo = ParachainStakingCandidateInfo(
            address: "collator-address",
            owner: owner,
            amount: AmountDecimal(value: 123.45),
            metadata: metadata,
            identity: AccountIdentity(name: "Collator"),
            subqueryData: SubqueryCollatorAprInfo(collatorId: "collator-address", apr: 12.5)
        )

        XCTAssertEqual(candidate.owner, owner)
        XCTAssertEqual(candidate.amount, AmountDecimal(value: 123.45))
        XCTAssertEqual(metadata.bond, BigUInt(1000))
        XCTAssertEqual(metadata.delegationCount, 2)
        XCTAssertEqual(metadata.totalCounted, BigUInt(900))
        XCTAssertEqual(metadata.lowestTopDelegationAmount, BigUInt(10))
        XCTAssertEqual(metadata.highestBottomDelegationAmount, BigUInt(20))
        XCTAssertEqual(metadata.lowestBottomDelegationAmount, BigUInt(5))
        XCTAssertEqual(metadata.topCapacity, .full)
        XCTAssertEqual(metadata.bottomCapacity, .partial)
        XCTAssertEqual(metadata.request?.amount, BigUInt(50))
        XCTAssertEqual(metadata.request?.whenExecutable, "16")
        XCTAssertEqual(metadata.status, .active)
        XCTAssertEqual(delegatorState.id, delegator)
        XCTAssertEqual(delegatorState.delegations.first?.owner, owner)
        XCTAssertEqual(delegatorState.delegations.first?.amount, BigUInt(77))
        XCTAssertEqual(delegatorState.total, BigUInt(100))
        XCTAssertEqual(delegatorState.lessTotal, BigUInt(25))
        XCTAssertEqual(delegatorState.status, .leaving)
        XCTAssertEqual(revokeRequest.delegator, delegator)
        XCTAssertEqual(revokeRequest.whenExecutable, 7)
        XCTAssertEqual(revokeRequest.action, .revoke(amount: BigUInt(12)))
        XCTAssertEqual(decreaseRequest.action, .decrease(amount: BigUInt(9)))
        XCTAssertEqual(idleStatus, .idle)
        XCTAssertEqual(leavingStatus, .leaving)
        XCTAssertEqual(emptyCapacity, .empty)
        XCTAssertEqual(activeDelegatorStatus, .active)
        XCTAssertTrue(candidateInfo.oversubscribed)
        XCTAssertTrue(candidateInfo.hasIdentity)
        XCTAssertEqual(candidateInfo.stakeReturn, .zero)
        XCTAssertEqual(candidateInfo, matchingCandidateInfo)
        XCTAssertThrowsError(try JSONDecoder().decode(CollatorStatus.self, from: data(from: #"["Unknown"]"#)))
        XCTAssertThrowsError(try JSONDecoder().decode(CapacityStatus.self, from: data(from: #"["Unknown"]"#)))
        XCTAssertThrowsError(try JSONDecoder().decode(DelegatorStatus.self, from: data(from: #"["Unknown"]"#)))
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                ParachainStakingDelegationAction.self,
                from: data(from: #"["unknown","1"]"#)
            )
        )
    }

    func testStakingPoolMember_whenDecoded_thenCalculatesRedeemableAndUnbondingChunks() throws {
        let payload = """
        {
          "poolId": "7",
          "points": "100",
          "unbondingEras": [
            { "era": "3", "value": "10" },
            ["5", "20"]
          ]
        }
        """

        let member = try JSONDecoder().decode(StakingPoolMember.self, from: data(from: payload))

        XCTAssertEqual(member.poolId.value, 7)
        XCTAssertEqual(member.points, BigUInt(100))
        XCTAssertEqual(member.lastRecordedRewardCounter, .zero)
        XCTAssertEqual(member.unbondingEras, [
            UnlockChunk(value: BigUInt(10), era: 3),
            UnlockChunk(value: BigUInt(20), era: 5)
        ])
        XCTAssertEqual(member.redeemable(inEra: 3), BigUInt(10))
        XCTAssertEqual(member.unbonding(inEra: 3), BigUInt(20))
        XCTAssertEqual(member.unbondings(inEra: 3), [UnlockChunk(value: BigUInt(20), era: 5)])
    }

    func testNftModels_whenDecodedAndQueried_thenUseMediaMetadataAndCollectionFallbacks() throws {
        let chain = makeChain(chainId: "ethereum")
        let opensea = AlchemyNftOpenseaInfo(
            floorPrice: 1.25,
            collectionName: "OpenSea Collection",
            collectionSlug: "open-sea-collection",
            safelistRequestStatus: "verified",
            imageUrl: "https://example.com/collection.png",
            description: "Collection description",
            externalUrl: "https://example.com",
            twitterUsername: "fearless",
            bannerImageUrl: "https://example.com/banner.png",
            lastIngestedAt: "2024-05-23T00:00:00Z"
        )
        let imageMedia = NFTMedia(
            thumbnail: "ipfs://thumbnail",
            mediaPath: "ipfs://image.png",
            format: "png"
        )
        let videoMedia = NFTMedia(
            thumbnail: nil,
            mediaPath: "https://example.com/video.mp4",
            format: "mp4"
        )
        let collection = NFTCollection(
            address: "0xcollection",
            numberOfTokens: 10,
            isSpam: false,
            title: nil,
            name: "Fallback Collection",
            creator: "creator",
            price: 1.5,
            media: [imageMedia],
            tokenType: .erc721,
            desc: "desc",
            opensea: opensea,
            chain: chain,
            totalSupply: "10",
            nfts: nil,
            availableNfts: nil
        )
        let mediaFallbackCollection = NFTCollection(
            address: "0xcollection",
            numberOfTokens: 10,
            isSpam: false,
            title: nil,
            name: "Media Collection",
            creator: "creator",
            price: 1.5,
            media: [imageMedia],
            tokenType: .erc721,
            desc: "desc",
            opensea: nil,
            chain: chain,
            totalSupply: "10",
            nfts: nil,
            availableNfts: nil
        )
        var nftOnlyFallbackCollection = NFTCollection(
            address: "0xcollection",
            numberOfTokens: 10,
            isSpam: false,
            title: nil,
            name: nil,
            creator: "creator",
            price: 1.5,
            media: [videoMedia],
            tokenType: .erc721,
            desc: "desc",
            opensea: nil,
            chain: chain,
            totalSupply: "10",
            nfts: nil,
            availableNfts: nil
        )
        let metadata = NFTMetadata(
            name: "Metadata Name",
            description: "Metadata description",
            image: "ipfs://metadata-image"
        )
        let nft = NFT(
            chain: chain,
            tokenId: "42",
            title: nil,
            description: nil,
            smartContract: "0xcontract",
            metadata: metadata,
            mediaThumbnail: nil,
            media: [videoMedia, imageMedia],
            tokenType: .erc721,
            collectionName: nil,
            collection: collection
        )
        let collectionFallbackNft = NFT(
            chain: chain,
            tokenId: "42",
            title: nil,
            description: nil,
            smartContract: nil,
            metadata: nil,
            mediaThumbnail: nil,
            media: nil,
            tokenType: nil,
            collectionName: nil,
            collection: collection
        )
        let tokenOnlyNft = NFT(
            chain: chain,
            tokenId: "7",
            title: nil,
            description: nil,
            smartContract: nil,
            metadata: nil,
            mediaThumbnail: nil,
            media: nil,
            tokenType: nil,
            collectionName: nil,
            collection: nil
        )
        let thumbnailOverrideNft = NFT(
            chain: chain,
            tokenId: "8",
            title: "Title Name",
            description: "Title description",
            smartContract: nil,
            metadata: nil,
            mediaThumbnail: "https://example.com/thumb-override.png",
            media: [imageMedia],
            tokenType: nil,
            collectionName: nil,
            collection: nil
        )
        var nftFallbackCollection = mediaFallbackCollection
        nftFallbackCollection.nfts = [thumbnailOverrideNft]
        nftOnlyFallbackCollection.nfts = [thumbnailOverrideNft]
        let etherscanPayload = """
        {"timeStamp":"1700000000","hash":"0xhash","tokenID":"42","tokenName":"Fearless NFT"}
        """
        let invalidEtherscanPayload = """
        {"timeStamp":"not-a-number"}
        """
        let alchemyPayload = """
        {
          "title": 123,
          "description": "Alchemy description",
          "media": [
            {
              "gateway": "https://example.com/nft.png",
              "thumbnail": "https://example.com/thumb.png",
              "raw": "ipfs://raw",
              "format": "png",
              "bytes": 512
            }
          ],
          "id": {
            "tokenId": "0x2a",
            "tokenMetadata": { "tokenType": "ERC721" }
          },
          "balance": "1",
          "contract": { "address": "0xcontract" },
          "metadata": {
            "name": "Alchemy Name",
            "description": "Alchemy metadata description",
            "backgroundColor": "ffffff",
            "poster": "https://example.com/poster.png"
          },
          "spamInfo": {
            "isSpam": "false",
            "classifications": ["Airdrop"]
          },
          "contractMetadata": {
            "address": "0xcollection",
            "totalBalance": 1,
            "numDistinctTokensOwned": 1,
            "isSpam": false,
            "tokenId": "0x2a",
            "name": "Collection",
            "title": "Collection title",
            "symbol": "COL",
            "totalSupply": "100",
            "tokenType": "ERC721",
            "contractDeployer": "0xdeployer",
            "deployedBlockNumber": 123,
            "openSea": {
              "floorPrice": 1.25,
              "collectionName": "OpenSea Collection",
              "collectionSlug": "open-sea-collection",
              "safelistRequestStatus": "verified",
              "imageUrl": "https://example.com/collection.png",
              "description": "Collection description",
              "externalUrl": "https://example.com",
              "twitterUsername": "fearless",
              "bannerImageUrl": "https://example.com/banner.png",
              "lastIngestedAt": "2024-05-23T00:00:00Z"
            },
            "media": [
              {
                "gateway": "https://example.com/collection-media.png",
                "thumbnail": "https://example.com/collection-thumb.png",
                "raw": "ipfs://collection-raw",
                "format": "png",
                "bytes": 128
              }
            ]
          }
        }
        """
        let wrappersPayload = """
        {
          "ownedNfts": [\(alchemyPayload)],
          "nfts": [\(alchemyPayload)],
          "owners": ["0xowner"]
        }
        """

        let etherscan = try JSONDecoder().decode(
            EtherscanNftResponseElement.self,
            from: data(from: etherscanPayload)
        )
        let invalidEtherscan = try JSONDecoder().decode(
            EtherscanNftResponseElement.self,
            from: data(from: invalidEtherscanPayload)
        )
        let missingTimestampEtherscan = try JSONDecoder().decode(
            EtherscanNftResponseElement.self,
            from: data(from: #"{}"#)
        )
        let alchemy = try JSONDecoder().decode(AlchemyNftInfo.self, from: data(from: alchemyPayload))
        let ownedResponse = try JSONDecoder().decode(
            AlchemyOwnedNftsResponse.self,
            from: data(from: wrappersPayload)
        )
        let nftsResponse = try JSONDecoder().decode(
            AlchemyNftsResponse.self,
            from: data(from: #"{"nfts":[\#(alchemyPayload)],"nextToken":"next"}"#)
        )
        let ownersResponse = try JSONDecoder().decode(
            AlchemyOwnersResponse.self,
            from: data(from: wrappersPayload)
        )

        XCTAssertEqual(metadata.imageURL?.absoluteString, "https://ipfs.io/ipfs/metadata-image")
        XCTAssertEqual(imageMedia.normalizedThumbnailURL?.absoluteString, "https://ipfs.io/ipfs/thumbnail")
        XCTAssertEqual(imageMedia.normalizedURL?.absoluteString, "https://ipfs.io/ipfs/image.png")
        XCTAssertTrue(imageMedia.isImage)
        XCTAssertFalse(imageMedia.isVideo)
        XCTAssertFalse(videoMedia.isImage)
        XCTAssertTrue(videoMedia.isVideo)
        XCTAssertEqual(nft.thumbnailURL?.absoluteString, "https://ipfs.io/ipfs/metadata-image")
        XCTAssertEqual(nft.displayDescription, "Metadata description")
        XCTAssertEqual(nft.displayName, "Metadata Name")
        XCTAssertEqual(collection.displayName, "OpenSea Collection")
        XCTAssertEqual(collection.displayImageUrl?.absoluteString, "https://example.com/collection.png")
        XCTAssertEqual(collection.displayThumbnailImageUrl?.absoluteString, "https://example.com/collection.png")
        XCTAssertEqual(mediaFallbackCollection.displayName, "Media Collection")
        XCTAssertEqual(mediaFallbackCollection.displayImageUrl?.absoluteString, "https://ipfs.io/ipfs/image.png")
        XCTAssertEqual(
            mediaFallbackCollection.displayThumbnailImageUrl?.absoluteString,
            "https://ipfs.io/ipfs/thumbnail"
        )
        XCTAssertEqual(nftFallbackCollection.displayImageUrl?.absoluteString, "https://ipfs.io/ipfs/image.png")
        XCTAssertEqual(nftOnlyFallbackCollection.displayName, "Title Name")
        XCTAssertEqual(nftOnlyFallbackCollection.displayImageUrl?.absoluteString, "https://example.com/thumb-override.png")
        XCTAssertEqual(
            nftOnlyFallbackCollection.displayThumbnailImageUrl?.absoluteString,
            "https://example.com/thumb-override.png"
        )
        XCTAssertEqual(thumbnailOverrideNft.thumbnailURL?.absoluteString, "https://example.com/thumb-override.png")
        XCTAssertEqual(thumbnailOverrideNft.displayDescription, "Title description")
        XCTAssertEqual(thumbnailOverrideNft.displayName, "Title Name")
        XCTAssertEqual(collectionFallbackNft.displayDescription, "Collection description")
        XCTAssertEqual(collectionFallbackNft.displayName, "OpenSea Collection #42")
        XCTAssertEqual(tokenOnlyNft.displayName, "#7")
        XCTAssertEqual(etherscan.date, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(etherscan.hash, "0xhash")
        XCTAssertLessThan(abs(invalidEtherscan.date.timeIntervalSinceNow), 2)
        XCTAssertLessThan(abs(missingTimestampEtherscan.date.timeIntervalSinceNow), 2)
        XCTAssertNil(alchemy.title)
        XCTAssertEqual(alchemy.description, "Alchemy description")
        XCTAssertEqual(alchemy.media?.first?.bytes, 512)
        XCTAssertEqual(alchemy.id?.tokenId, "0x2a")
        XCTAssertEqual(alchemy.id?.tokenMetadata?.tokenType, .erc721)
        XCTAssertEqual(alchemy.contract?.address, "0xcontract")
        XCTAssertEqual(alchemy.metadata?.name, "Alchemy Name")
        XCTAssertEqual(alchemy.spamInfo?.classifications, ["Airdrop"])
        XCTAssertEqual(alchemy.contractMetadata?.openSea?.collectionName, "OpenSea Collection")
        XCTAssertEqual(ownedResponse.ownedNfts?.count, 1)
        XCTAssertEqual(nftsResponse.nfts?.count, 1)
        XCTAssertEqual(nftsResponse.nextToken, "next")
        XCTAssertEqual(ownersResponse.owners, ["0xowner"])
    }

    func testPickerAndSelectionViewModels_whenInitialized_thenStoreProvidedState() {
        let remoteImage = RemoteImageViewModel(url: URL(string: "https://example.com/icon.svg")!)
        let iconModel = IconWithTitleViewModel(
            icon: nil,
            remoteImageViewModel: remoteImage,
            title: "SORA"
        )
        let sameIconModel = IconWithTitleViewModel(
            icon: nil,
            remoteImageViewModel: remoteImage,
            title: "SORA"
        )
        let sortModel = SortPickerTableViewCellModel(
            title: "Total stake",
            switchIsOn: true,
            sortOption: .totalStake(assetSymbol: "DOT")
        )
        let switchModel = TitleSwitchTableViewCellModel(
            icon: nil,
            title: "Enabled",
            switchIsOn: false
        )
        let selectableModel = SelectableSubtitleListViewModel(
            title: "Validator",
            subtitle: "Active",
            isSelected: true,
            isExpand: true
        )
        let networkModel = SelectNetworkViewModel(
            chainName: "Kusama",
            iconViewModel: nil
        )

        XCTAssertEqual(iconModel, sameIconModel)
        XCTAssertEqual(iconModel.remoteImageViewModel?.url.absoluteString, "https://example.com/icon.svg")
        XCTAssertEqual(sortModel.title, "Total stake")
        XCTAssertTrue(sortModel.switchIsOn)
        XCTAssertEqual(sortModel.sortOption, .totalStake(assetSymbol: "DOT"))
        XCTAssertEqual(switchModel.title, "Enabled")
        XCTAssertFalse(switchModel.switchIsOn)
        XCTAssertEqual(selectableModel.title, "Validator")
        XCTAssertEqual(selectableModel.subtitle, "Active")
        XCTAssertTrue(selectableModel.isSelected)
        XCTAssertTrue(selectableModel.isExpand)
        XCTAssertEqual(networkModel.chainName, "Kusama")
        XCTAssertNil(networkModel.iconViewModel)
        XCTAssertTrue(networkModel.canEdit)
    }

    func testExtrinsicIndexWrapper_whenDecoded_thenReadsLastDashSeparatedComponent() throws {
        let validData = try XCTUnwrap("\"100-42\"".data(using: .utf8))
        let invalidData = try XCTUnwrap("\"bad-index\"".data(using: .utf8))

        let wrapper = try JSONDecoder().decode(ExtrinisicIndexWrapper.self, from: validData)

        XCTAssertEqual(wrapper.value, 42)
        XCTAssertThrowsError(try JSONDecoder().decode(ExtrinisicIndexWrapper.self, from: invalidData))
    }

    func testSubqueryEraValidatorInfo_whenJsonContainsRequiredFields_thenCreatesModel() {
        let validJson = JSON.dictionaryValue([
            "era": .unsignedIntValue(42),
            "address": .stringValue("validator-address")
        ])
        let missingAddressJson = JSON.dictionaryValue([
            "era": .unsignedIntValue(42)
        ])

        let info = SubqueryEraValidatorInfo(from: validJson)

        XCTAssertEqual(info?.era, 42)
        XCTAssertEqual(info?.address, "validator-address")
        XCTAssertNil(SubqueryEraValidatorInfo(from: missingAddressJson))
    }

    func testBlockExplorerHistoryResponses_whenDecoded_thenNormalizeAmountsAndTimestamps() throws {
        let kaiaPayload = """
        {"success":true,"code":0,"result":[{"blockNumber":1,"createdAt":1700000000,"txHash":"kaia","amount":"10","txFee":"2"}]}
        """
        let viscanPayload = """
        {"data":[{"blockNumber":2,"timestamp":1700000001,"hash":"viscan","value":"11","fee":1.25}]}
        """
        let zchainPayload = """
        {"data":[{"bn":3,"ti":1700000002,"h":"zchain","v":"12","tf":"3","f":{"a":"from"},"t":{"a":"to"}}]}
        """
        let etherscanPayload = """
        {"timeStamp":"1700000003","hash":"etherscan","value":"13","gas":"1","gasPrice":"2","gasUsed":"3"}
        """

        let kaia = try JSONDecoder().decode(KaiaHistoryResponse.self, from: data(from: kaiaPayload))
        let viscan = try JSONDecoder().decode(ViscanHistoryResponse.self, from: data(from: viscanPayload))
        let zchain = try JSONDecoder().decode(ZChainHistoryResponse.self, from: data(from: zchainPayload))
        let etherscan = try JSONDecoder().decode(EtherscanHistoryElement.self, from: data(from: etherscanPayload))

        XCTAssertEqual(kaia.result?.first?.amount, BigUInt(10))
        XCTAssertEqual(kaia.result?.first?.txFee, BigUInt(2))
        XCTAssertEqual(kaia.result?.first?.timestampInSeconds, 1_700_000_000)
        XCTAssertEqual(viscan.data?.first?.value, BigUInt(11))
        XCTAssertEqual(viscan.data?.first?.fee, Decimal(string: "1.25"))
        XCTAssertEqual(viscan.data?.first?.timestampInSeconds, 1_700_000_001)
        XCTAssertEqual(zchain.data?.first?.value, BigUInt(12))
        XCTAssertEqual(zchain.data?.first?.fee, BigUInt(3))
        XCTAssertEqual(zchain.data?.first?.from?.address, "from")
        XCTAssertEqual(zchain.data?.first?.timestampInSeconds, 1_700_000_002)
        XCTAssertEqual(etherscan.value, BigUInt(13))
        XCTAssertEqual(etherscan.gasUsed, BigUInt(3))
        XCTAssertEqual(etherscan.timestampInSeconds, 1_700_000_003)
    }

    func testSubsquidHistoryResponse_whenDecoded_thenExposesLabelsTimestampsAndRewardData() throws {
        let address = "sender"
        let asset = makeHistoryAsset()
        let chain = makeChain(chainId: "subsquid-chain", assets: [asset])
        let payload = """
        {
            "historyElements": [
                {
                    "id": "reward-1",
                    "timestamp": "1700000004000",
                    "address": "stash",
                    "reward": {
                        "amount": "10",
                        "isReward": true,
                        "era": 12,
                        "validator": "validator",
                        "stash": "stash",
                        "eventIdx": "1-2",
                        "assetId": "asset"
                    }
                },
                {
                    "id": "extrinsic-1",
                    "timestamp": "bad-timestamp",
                    "address": "caller",
                    "extrinsic": {
                        "hash": "hash",
                        "module": "staking",
                        "call": "bond",
                        "fee": "3",
                        "success": false,
                        "assetId": "asset"
                    }
                },
                {
                    "id": "transfer-1",
                    "timestamp": "1700000005000",
                    "address": "sender",
                    "transfer": {
                        "amount": "20",
                        "to": "receiver",
                        "from": "sender",
                        "fee": "1",
                        "block": "42",
                        "extrinsicId": "42-0",
                        "extrinsicHash": "transfer-hash",
                        "success": true,
                        "assetId": "asset"
                    }
                }
            ]
        }
        """

        let response = try JSONDecoder().decode(SubsquidHistoryResponse.self, from: data(from: payload))

        XCTAssertEqual(response.historyElements.count, 3)
        XCTAssertEqual(response.data.count, 3)
        XCTAssertEqual(response.historyElements[0].identifier, "reward-1")
        XCTAssertEqual(response.historyElements[0].itemBlockNumber, 0)
        XCTAssertEqual(response.historyElements[0].itemExtrinsicIndex, 0)
        XCTAssertEqual(response.historyElements[0].itemTimestamp, 1_700_000_004)
        XCTAssertEqual(response.historyElements[0].label.rawValue, WalletRemoteHistorySourceLabel.rewards.rawValue)
        XCTAssertEqual(response.historyElements[0].rewardInfo?.amount, "10")
        XCTAssertEqual(response.historyElements[0].rewardInfo?.era, 12)
        XCTAssertEqual(response.historyElements[0].rewardInfo?.validator, "validator")
        XCTAssertEqual(
            response.historyElements[0]
                .createTransactionForAddress(address, chain: chain, asset: asset)
                .transactionId,
            "reward-1"
        )

        XCTAssertEqual(response.historyElements[1].itemBlockNumber, 0)
        XCTAssertEqual(response.historyElements[1].itemExtrinsicIndex, 0)
        XCTAssertEqual(response.historyElements[1].itemTimestamp, 0)
        XCTAssertEqual(response.historyElements[1].label.rawValue, WalletRemoteHistorySourceLabel.extrinsics.rawValue)
        XCTAssertEqual(response.historyElements[1].extrinsic?.module, "staking")
        XCTAssertFalse(response.historyElements[1].extrinsic?.success ?? true)
        XCTAssertEqual(
            response.historyElements[1]
                .createTransactionForAddress(address, chain: chain, asset: asset)
                .transactionId,
            "extrinsic-1"
        )

        XCTAssertEqual(response.historyElements[2].itemBlockNumber, 0)
        XCTAssertEqual(response.historyElements[2].itemExtrinsicIndex, 0)
        XCTAssertEqual(response.historyElements[2].label.rawValue, WalletRemoteHistorySourceLabel.transfers.rawValue)
        XCTAssertEqual(response.historyElements[2].transfer?.receiver, "receiver")
        XCTAssertEqual(response.historyElements[2].transfer?.sender, "sender")
        XCTAssertEqual(response.historyElements[2].transfer?.success, true)
        XCTAssertEqual(
            response.historyElements[2]
                .createTransactionForAddress(address, chain: chain, asset: asset)
                .transactionId,
            "transfer-1"
        )
    }

    func testGiantsquidResponse_whenDecoded_thenCombinesHistoryAndRewardProtocolData() throws {
        let timestamp = "2024-01-02T03:04:05.000Z"
        let address = "sender"
        let asset = makeHistoryAsset()
        let chain = makeChain(chainId: "giantsquid-response-chain", assets: [asset])
        let payload = """
        {
            "data": {
                "transfers": [
                    {
                        "id": "response-transfer",
                        "transfer": {
                            "amount": "10",
                            "to": { "id": "receiver" },
                            "from": { "id": "sender" },
                            "success": true,
                            "extrinsicHash": "transfer-hash",
                            "timestamp": "\(timestamp)",
                            "blockNumber": 10,
                            "type": "transfer",
                            "feeAmount": "1",
                            "blockHash": "block-hash"
                        }
                    }
                ],
                "stakingRewards": [
                    {
                        "amount": "20",
                        "era": 3,
                        "accountId": "stash",
                        "validator": "validator",
                        "timestamp": "\(timestamp)",
                        "extrinsicHash": "reward-hash",
                        "blockNumber": 11,
                        "id": "reward-id"
                    },
                    {
                        "amount": "21",
                        "timestamp": 1700000000,
                        "extrinsicHash": "numeric-reward-hash"
                    }
                ],
                "bonds": [
                    {
                        "id": "bond-id",
                        "accountId": "stash",
                        "amount": "30",
                        "blockNumber": 12,
                        "extrinsicHash": "bond-hash",
                        "success": true,
                        "timestamp": "\(timestamp)",
                        "type": "bond"
                    }
                ],
                "slashes": [
                    {
                        "id": "slash-id",
                        "accountId": "stash",
                        "amount": "40",
                        "blockNumber": 13,
                        "era": 4,
                        "timestamp": "\(timestamp)"
                    }
                ]
            }
        }
        """
        let fallbackTransferPayload = """
        {
            "amount": "55",
            "timestamp": "\(timestamp)"
        }
        """

        let response = try JSONDecoder().decode(GiantsquidResponse.self, from: data(from: payload))
        let fallbackTransfer = try JSONDecoder().decode(
            GiantsquidTransfer.self,
            from: data(from: fallbackTransferPayload)
        )
        let emptyResponse = GiantsquidResponseData(transfers: nil, stakingRewards: nil, bonds: nil, slashes: nil)
        let history = response.data.history
        let rewards = response.data.data

        XCTAssertEqual(history.count, 5)
        XCTAssertEqual(rewards.count, 2)
        XCTAssertTrue(emptyResponse.history.isEmpty)
        XCTAssertTrue(emptyResponse.data.isEmpty)
        XCTAssertEqual(history.map(\.label.rawValue), [
            WalletRemoteHistorySourceLabel.transfers.rawValue,
            WalletRemoteHistorySourceLabel.rewards.rawValue,
            WalletRemoteHistorySourceLabel.rewards.rawValue,
            WalletRemoteHistorySourceLabel.extrinsics.rawValue,
            WalletRemoteHistorySourceLabel.extrinsics.rawValue
        ])

        let transfer = try XCTUnwrap(history.first as? GiantsquidTransfer)
        XCTAssertEqual(transfer.identifier, "transfer-hash")
        XCTAssertEqual(transfer.to?.id, "receiver")
        XCTAssertEqual(transfer.from?.id, "sender")
        XCTAssertEqual(transfer.itemTimestamp, 1_704_164_645)
        XCTAssertEqual(transfer.itemBlockNumber, 0)
        XCTAssertEqual(transfer.itemExtrinsicIndex, 0)
        XCTAssertEqual(
            transfer.createTransactionForAddress(address, chain: chain, asset: asset).transactionId,
            "transfer-hash"
        )
        XCTAssertEqual(fallbackTransfer.identifier, timestamp + "55")

        let reward = try XCTUnwrap(rewards.first as? GiantsquidReward)
        XCTAssertEqual(reward.identifier, "reward-id")
        XCTAssertEqual(reward.address, "stash")
        XCTAssertEqual(reward.rewardInfo?.amount, "20")
        XCTAssertEqual(reward.isReward, true)
        XCTAssertEqual(reward.stash, "stash")
        XCTAssertEqual(reward.eventIdx, "reward-id")
        XCTAssertNil(reward.assetId)
        XCTAssertEqual(reward.itemBlockNumber, 0)
        XCTAssertEqual(reward.itemExtrinsicIndex, 0)
        XCTAssertEqual(reward.itemTimestamp, 1_704_164_645)
        XCTAssertEqual(
            reward.createTransactionForAddress(address, chain: chain, asset: asset).transactionId,
            "reward-id"
        )

        let numericTimestampReward = try XCTUnwrap(rewards.last as? GiantsquidReward)
        XCTAssertEqual(numericTimestampReward.address, "")
        XCTAssertEqual(numericTimestampReward.timestamp, "1700000000")
        XCTAssertEqual(numericTimestampReward.identifier, "numeric-reward-hash")
        XCTAssertEqual(numericTimestampReward.itemTimestamp, 0)

        let bond = try XCTUnwrap(history[3] as? GiantsquidBond)
        XCTAssertEqual(bond.identifier, "bond-id")
        XCTAssertEqual(bond.itemBlockNumber, 0)
        XCTAssertEqual(bond.itemExtrinsicIndex, 0)
        XCTAssertEqual(bond.itemTimestamp, 1_704_164_645)
        XCTAssertEqual(bond.label.rawValue, WalletRemoteHistorySourceLabel.extrinsics.rawValue)
        XCTAssertEqual(
            bond.createTransactionForAddress(address, chain: chain, asset: asset).transactionId,
            "bond-id"
        )

        let slash = try XCTUnwrap(history[4] as? GiantsquidSlash)
        XCTAssertEqual(slash.identifier, "slash-id")
        XCTAssertEqual(slash.itemBlockNumber, 0)
        XCTAssertEqual(slash.itemExtrinsicIndex, 0)
        XCTAssertEqual(slash.itemTimestamp, 1_704_164_645)
        XCTAssertEqual(slash.label.rawValue, WalletRemoteHistorySourceLabel.extrinsics.rawValue)
        XCTAssertEqual(
            slash.createTransactionForAddress(address, chain: chain, asset: asset).transactionId,
            "slash-id"
        )
    }

    func testArrowsquidHistoryResponse_whenDecoded_thenExposesRewardAndTransferProtocolViews() throws {
        let payload = """
        {
            "historyElements": [
                {
                    "id": "reward-edge",
                    "timestamp": 1700000008,
                    "address": "stash",
                    "extrinsicHash": "reward-hash",
                    "success": true,
                    "reward": {
                        "amount": "50",
                        "stash": "stash",
                        "assetId": "asset",
                        "era": 9,
                        "validator": "validator",
                        "eventIdx": "event-idx"
                    }
                },
                {
                    "id": "transfer-edge",
                    "timestamp": 1700000009,
                    "address": "sender",
                    "extrinsicHash": "transfer-hash",
                    "success": false,
                    "transfer": {
                        "amount": "60",
                        "to": "receiver",
                        "from": "sender",
                        "fee": "1",
                        "block": "100",
                        "extrinsicId": "100-1",
                        "extrinsicHash": "transfer-hash",
                        "success": false,
                        "assetId": "asset"
                    }
                }
            ]
        }
        """

        let response = try JSONDecoder().decode(ArrowsquidHistoryResponse.self, from: data(from: payload))

        XCTAssertEqual(response.data.count, 2)
        XCTAssertEqual(response.historyElements[0].identifier, "reward-edge")
        XCTAssertEqual(response.historyElements[0].itemTimestamp, 1_700_000_008)
        XCTAssertEqual(response.historyElements[0].label.rawValue, WalletRemoteHistorySourceLabel.rewards.rawValue)
        XCTAssertEqual(response.historyElements[0].rewardInfo?.amount, "50")
        XCTAssertEqual(response.historyElements[0].timestampInSeconds, 1_700_000_008)
        XCTAssertFalse(response.historyElements[0].timestamp.isEmpty)

        XCTAssertEqual(response.historyElements[1].label.rawValue, WalletRemoteHistorySourceLabel.transfers.rawValue)
        XCTAssertEqual(response.historyElements[1].transfer?.receiver, "receiver")
        XCTAssertEqual(response.historyElements[1].transfer?.success, false)
    }

    func testReefResponseData_whenDecoded_thenCombinesEdgesAndContext() throws {
        let timestamp = "2024-01-02T03:04:05.000Z"
        let payload = """
        {
            "transfersConnection": {
                "edges": [
                    {
                        "node": {
                            "amount": "10",
                            "to": { "id": "receiver" },
                            "from": { "id": "sender" },
                            "success": true,
                            "extrinsicHash": "transfer-hash",
                            "timestamp": "\(timestamp)",
                            "blockNumber": 10,
                            "type": "transfer"
                        }
                    }
                ],
                "pageInfo": { "startCursor": "start", "endCursor": "end", "hasNextPage": false },
                "totalCount": 1
            },
            "stakingsConnection": {
                "edges": [
                    {
                        "node": {
                            "amount": "20",
                            "accountId": "stash",
                            "timestamp": "\(timestamp)",
                            "extrinsicHash": "reward-hash"
                        }
                    }
                ],
                "pageInfo": { "endCursor": "reward-end" },
                "totalCount": 1
            },
            "extrinsicsConnection": {
                "edges": [
                    {
                        "node": {
                            "id": "extrinsic-id",
                            "timestamp": "\(timestamp)",
                            "section": "balances",
                            "method": "transfer",
                            "hash": "0xhash-42",
                            "status": "success",
                            "type": "extrinsic"
                        }
                    }
                ],
                "pageInfo": {},
                "totalCount": 1
            }
        }
        """

        let response = try JSONDecoder().decode(ReefResponseData.self, from: data(from: payload))
        let history = response.history
        let pageInfo = try XCTUnwrap(response.transfersConnection?.pageInfo)
        let emptyPageInfo = ReefSubsquidPageInfo(startCursor: nil, endCursor: nil, hasNextPage: nil)
        let startOnlyPageInfo = ReefSubsquidPageInfo(startCursor: "start-only", endCursor: nil, hasNextPage: true)
        let endOnlyPageInfo = ReefSubsquidPageInfo(startCursor: nil, endCursor: "end-only", hasNextPage: false)
        let emptyResponse = ReefResponseData(
            transfersConnection: nil,
            stakingsConnection: nil,
            extrinsicsConnection: nil
        )

        XCTAssertEqual(history.count, 3)
        XCTAssertEqual(response.data.count, 1)
        XCTAssertTrue(emptyResponse.history.isEmpty)
        XCTAssertTrue(emptyResponse.data.isEmpty)
        XCTAssertEqual(history.map(\.label.rawValue), [
            WalletRemoteHistorySourceLabel.transfers.rawValue,
            WalletRemoteHistorySourceLabel.rewards.rawValue,
            WalletRemoteHistorySourceLabel.extrinsics.rawValue
        ])
        XCTAssertEqual(pageInfo.toContext(), ["startCursor": "start", "endCursor": "end"])
        XCTAssertNil(emptyPageInfo.toContext())
        XCTAssertEqual(startOnlyPageInfo.toContext(), ["startCursor": "start-only"])
        XCTAssertEqual(endOnlyPageInfo.toContext(), ["endCursor": "end-only"])

        let extrinsic = try XCTUnwrap(history[2] as? GiantsquidExtrinsic)
        XCTAssertEqual(extrinsic.identifier, "extrinsic-id")
        XCTAssertEqual(extrinsic.extrinsicHash, "0xhash")
        XCTAssertEqual(extrinsic.itemTimestamp, 1_704_164_645)
    }

    func testSoraSubsquidHistoryConnection_whenDecoded_thenNormalizesPaginationAssetsAndTimestamps() throws {
        let payload = """
        {
            "historyElementsConnection": {
                "edges": [
                    {
                        "node": {
                            "id": "sora-history",
                            "address": "address",
                            "blockHash": "block",
                            "blockHeight": 99,
                            "method": "swap",
                            "name": "Swap",
                            "module": "liquidityProxy",
                            "networkFee": "1",
                            "timestamp": 1779398268000,
                            "execution": { "success": true },
                            "data": {
                                "era": 1,
                                "payee": "payee",
                                "stash": "stash",
                                "amount": "10",
                                "to": "receiver",
                                "from": "sender",
                                "targetAssetId": "target",
                                "baseAssetId": "base",
                                "assetId": "asset",
                                "baseAssetAmount": "20",
                                "targetAssetAmount": "30",
                                "sidechainAddress": "sidechain",
                                "requestHash": "request"
                            }
                        }
                    }
                ],
                "pageInfo": {
                    "startCursor": "start",
                    "endCursor": "end",
                    "hasNextPage": false,
                    "hasPreviousPage": true
                },
                "totalCount": 1
            }
        }
        """

        let response = try JSONDecoder().decode(SoraSubsquidHistoryConnectionResponse.self, from: data(from: payload))
        let connection = response.historyElementsConnection
        let node = try XCTUnwrap(connection.edges.first?.node)
        let historyData = try XCTUnwrap(node.data)
        let pageInfo = try XCTUnwrap(connection.pageInfo)
        let asset = makeHistoryAsset()
        let chain = makeChain(chainId: "sora-chain", assets: [asset])
        let transaction = node.createTransactionForAddress("address", chain: chain, asset: asset)

        XCTAssertEqual(connection.totalCount, 1)
        XCTAssertEqual(pageInfo.toPaginationContext(), ["startCursor": "start", "endCursor": "end"])
        XCTAssertEqual(pageInfo.startCursor, "start")
        XCTAssertEqual(pageInfo.endCursor, "end")
        XCTAssertEqual(pageInfo.hasNextPage, false)
        XCTAssertEqual(pageInfo.hasPreviousPage, true)
        XCTAssertEqual(node.identifier, "sora-history")
        XCTAssertEqual(node.address, "address")
        XCTAssertEqual(node.blockHash, "block")
        XCTAssertEqual(node.blockHeight, 99)
        XCTAssertEqual(node.method, "swap")
        XCTAssertEqual(node.name, "Swap")
        XCTAssertEqual(node.module, "liquidityProxy")
        XCTAssertEqual(node.networkFee, "1")
        XCTAssertEqual(node.itemBlockNumber, 0)
        XCTAssertEqual(node.itemExtrinsicIndex, 0)
        XCTAssertEqual(node.itemTimestamp, 1_779_398_268)
        XCTAssertEqual(node.label.rawValue, WalletRemoteHistorySourceLabel.extrinsics.rawValue)
        XCTAssertEqual(node.execution?.success, true)
        XCTAssertEqual(historyData.anyAssetId, "target")
        XCTAssertEqual(historyData.era, 1)
        XCTAssertEqual(historyData.payee, "payee")
        XCTAssertEqual(historyData.stash, "stash")
        XCTAssertEqual(historyData.amount, "10")
        XCTAssertEqual(historyData.to, "receiver")
        XCTAssertEqual(historyData.from, "sender")
        XCTAssertEqual(historyData.targetAssetId, "target")
        XCTAssertEqual(historyData.baseAssetId, "base")
        XCTAssertEqual(historyData.assetId, "asset")
        XCTAssertEqual(historyData.baseAssetAmount, "20")
        XCTAssertEqual(historyData.targetAssetAmount, "30")
        XCTAssertEqual(historyData.sidechainAddress, "sidechain")
        XCTAssertEqual(historyData.requestHash, "request")
        XCTAssertEqual(transaction.transactionId, "sora-history")
        XCTAssertEqual(transaction.type, TransactionType.swap.rawValue)
        XCTAssertEqual(transaction.assetId, "target")

        let secondsPayload = """
        {
            "historyElementsConnection": {
                "edges": [
                    { "node": { "id": "seconds-history", "timestamp": 1779398268 } }
                ],
                "totalCount": 1
            }
        }
        """
        let secondsResponse = try JSONDecoder().decode(
            SoraSubsquidHistoryConnectionResponse.self,
            from: data(from: secondsPayload)
        )

        XCTAssertEqual(secondsResponse.historyElementsConnection.edges.first?.node.itemTimestamp, 1_779_398_268)
        let fallbackAssetData = try JSONDecoder().decode(
            SoraSubsquidHistoryElementData.self,
            from: data(from: #"{ "assetId": "asset" }"#)
        )
        let baseAssetData = try JSONDecoder().decode(
            SoraSubsquidHistoryElementData.self,
            from: data(from: #"{ "baseAssetId": "base" }"#)
        )
        let nilTimestampElement = SoraSubsquidHistoryElement(
            id: "nil-timestamp",
            address: nil,
            blockHash: nil,
            blockHeight: nil,
            data: nil,
            method: nil,
            name: nil,
            module: nil,
            networkFee: nil,
            timestamp: nil,
            execution: nil
        )

        XCTAssertEqual(fallbackAssetData.anyAssetId, "asset")
        XCTAssertEqual(baseAssetData.anyAssetId, "base")
        XCTAssertEqual(nilTimestampElement.itemTimestamp, 0)
    }

    func testParachainSubsquidRewards_whenDecoded_thenFiltersByAccountAndNormalizesTimestamp() throws {
        let payload = """
        {
            "rewards": [
                {
                    "id": "reward-1",
                    "accountId": "account-1",
                    "timestamp": "2024-01-02T03:04:05.000000+0000",
                    "blockNumber": 42,
                    "amount": "123"
                },
                {
                    "id": "reward-2",
                    "accountId": "account-2",
                    "timestamp": "2024-01-02T03:04:06.000000+0000",
                    "blockNumber": 43,
                    "amount": "456"
                }
            ]
        }
        """

        let response = try JSONDecoder().decode(SubsquidDelegatorRewardsData.self, from: data(from: payload))
        let filteredRewards = response.rewardHistory(for: "account-1")

        XCTAssertEqual(response.rewards.count, 2)
        XCTAssertEqual(filteredRewards.count, 1)
        XCTAssertEqual(filteredRewards.first?.id, "reward-1")
        XCTAssertEqual(filteredRewards.first?.type.rawValue, SubqueryDelegationAction.reward.rawValue)
        XCTAssertEqual(filteredRewards.first?.timestampInSeconds, "1704164645")
        XCTAssertEqual(filteredRewards.first?.blockNumber, 42)
        XCTAssertEqual(filteredRewards.first?.amount, BigUInt(123))
        XCTAssertTrue(response.rewardHistory(for: "missing").isEmpty)
    }

    func testSubsquidCollatorAprResponse_whenAprMissing_thenUsesDefaultAndProtocolView() throws {
        let payload = """
        {
            "stakers": [
                { "stashId": "collator-1", "apr24h": 12.5 },
                { "stashId": "collator-2" }
            ]
        }
        """

        let response = try JSONDecoder().decode(SubsquidCollatorAprResponse.self, from: data(from: payload))

        XCTAssertEqual(response.stakers.count, 2)
        XCTAssertEqual(response.stakers[0].stashId, "collator-1")
        XCTAssertEqual(response.stakers[0].apr, 12.5)
        XCTAssertEqual(response.stakers[0].collatorId, "collator-1")
        XCTAssertEqual(response.stakers[1].stashId, "collator-2")
        XCTAssertEqual(response.stakers[1].apr24h, 999)
        XCTAssertEqual(response.collatorAprInfos.count, 2)
        XCTAssertEqual(response.collatorAprInfos[1].collatorId, "collator-2")
        XCTAssertEqual(response.collatorAprInfos[1].apr, 999)
    }

    func testSoraSubqueryPriceResponse_whenDecoded_thenSupportsNodesAndPiEdgesShapes() throws {
        let nodesPayload = """
        {
            "entities": {
                "nodes": [
                    {
                        "id": "xor",
                        "priceUSD": "5.25",
                        "priceChangeDay": 0.125
                    }
                ],
                "pageInfo": {
                    "hasNextPage": true,
                    "endCursor": "nodes-end"
                }
            }
        }
        """
        let edgesPayload = """
        {
            "entities": {
                "edges": [
                    {
                        "node": {
                            "id": "val",
                            "priceUSD": null,
                            "priceChangeDay": null
                        }
                    }
                ],
                "pageInfo": {
                    "hasNextPage": false,
                    "endCursor": "edges-end"
                }
            }
        }
        """
        let emptyPayload = """
        {
            "entities": {
                "pageInfo": {
                    "hasNextPage": false
                }
            }
        }
        """

        let nodesResponse = try JSONDecoder().decode(
            SoraSubqueryPriceResponse.self,
            from: data(from: nodesPayload)
        )
        let edgesResponse = try JSONDecoder().decode(
            SoraSubqueryPriceResponse.self,
            from: data(from: edgesPayload)
        )
        let emptyResponse = try JSONDecoder().decode(
            SoraSubqueryPriceResponse.self,
            from: data(from: emptyPayload)
        )

        XCTAssertEqual(nodesResponse.entities.nodes.count, 1)
        XCTAssertEqual(nodesResponse.entities.nodes.first?.id, "xor")
        XCTAssertEqual(nodesResponse.entities.nodes.first?.priceUsd, "5.25")
        XCTAssertEqual(nodesResponse.entities.nodes.first?.priceChangeDay, Decimal(string: "0.125"))
        XCTAssertEqual(nodesResponse.entities.pageInfo.toContext(), ["endCursor": "nodes-end"])
        XCTAssertEqual(nodesResponse.entities.pageInfo.hasNextPage, true)

        XCTAssertEqual(edgesResponse.entities.nodes.count, 1)
        XCTAssertEqual(edgesResponse.entities.nodes.first?.id, "val")
        XCTAssertNil(edgesResponse.entities.nodes.first?.priceUsd)
        XCTAssertNil(edgesResponse.entities.nodes.first?.priceChangeDay)
        XCTAssertEqual(edgesResponse.entities.pageInfo.toContext(), ["endCursor": "edges-end"])
        XCTAssertEqual(edgesResponse.entities.pageInfo.hasNextPage, false)

        XCTAssertTrue(emptyResponse.entities.nodes.isEmpty)
        XCTAssertNil(emptyResponse.entities.pageInfo.toContext())
    }

    func testSubqueryPageAndRewardData_whenDecoded_thenExposeContextAndLabels() throws {
        let pagePayload = """
        {"startCursor":"start","endCursor":"end","hasNextPage":true}
        """
        let emptyPagePayload = """
        {"hasNextPage":false}
        """
        let rewardPayload = """
        {
            "historyElements": {
                "nodes": [
                    {
                        "id": "reward-1",
                        "timestamp": "1700000006",
                        "address": "stash",
                        "reward": {
                            "amount": "100",
                            "isReward": true,
                            "era": 8,
                            "validator": "validator",
                            "stash": "stash",
                            "eventIdx": 3,
                            "assetId": "asset"
                        }
                    },
                    {
                        "id": "extrinsic-1",
                        "timestamp": "bad-timestamp",
                        "address": "caller",
                        "extrinsic": {
                            "hash": "hash",
                            "module": "balances",
                            "call": "transfer",
                            "fee": "1",
                            "success": true,
                            "assetId": "asset"
                        }
                    },
                    {
                        "id": "transfer-1",
                        "timestamp": "1700000007",
                        "address": "sender",
                        "transfer": {
                            "amount": "9",
                            "to": "receiver",
                            "from": "sender",
                            "fee": null,
                            "block": "50",
                            "extrinsicId": "50-1",
                            "extrinsicHash": "transfer-hash",
                            "success": false,
                            "assetId": "asset"
                        }
                    }
                ]
            }
        }
        """

        let page = try JSONDecoder().decode(SubqueryPageInfo.self, from: data(from: pagePayload))
        let emptyPage = try JSONDecoder().decode(SubqueryPageInfo.self, from: data(from: emptyPagePayload))
        let rewards = try JSONDecoder().decode(SubqueryRewardOrSlashData.self, from: data(from: rewardPayload))

        XCTAssertEqual(page.toContext(), ["startCursor": "start", "endCursor": "end"])
        XCTAssertNil(emptyPage.toContext())
        XCTAssertEqual(page.hasNextPage, true)
        XCTAssertEqual(rewards.data.count, 3)

        let reward = try XCTUnwrap(rewards.historyElements.nodes.first)
        XCTAssertEqual(reward.identifier, "reward-1")
        XCTAssertEqual(reward.itemTimestamp, 1_700_000_006)
        XCTAssertEqual(reward.label.rawValue, WalletRemoteHistorySourceLabel.rewards.rawValue)
        XCTAssertEqual(reward.rewardInfo?.eventIdx, "3")
        XCTAssertEqual(reward.rewardInfo?.amount, "100")

        XCTAssertEqual(rewards.historyElements.nodes[1].itemTimestamp, 0)
        XCTAssertEqual(rewards.historyElements.nodes[1].label.rawValue, WalletRemoteHistorySourceLabel.extrinsics.rawValue)
        XCTAssertEqual(rewards.historyElements.nodes[1].extrinsic?.call, "transfer")
        XCTAssertEqual(rewards.historyElements.nodes[2].label.rawValue, WalletRemoteHistorySourceLabel.transfers.rawValue)
        XCTAssertEqual(rewards.historyElements.nodes[2].transfer?.receiver, "receiver")
        XCTAssertFalse(rewards.historyElements.nodes[2].transfer?.success ?? true)
    }

    func testSubqueryDelegatorHistoryData_whenBuilt_thenFiltersHistoryByDelegatorAddress() throws {
        let unknownAction = try JSONDecoder().decode(SubqueryDelegationAction.self, from: data(from: "99"))
        let response = SubqueryDelegatorHistoryData(
            delegators: SubqueryDelegatorHistoryData.HistoryElements(
                nodes: [
                    SubqueryDelegatorHistoryElement(
                        id: "address-1",
                        delegatorHistoryElements: SubqueryDelegatorHistoryNodes(
                            nodes: [
                                SubqueryDelegatorHistoryItem(
                                    id: "history-1",
                                    type: .reward,
                                    timestampInSeconds: "1700000000",
                                    blockNumber: 42,
                                    amount: BigUInt(123)
                                )
                            ]
                        )
                    ),
                    SubqueryDelegatorHistoryElement(
                        id: "address-2",
                        delegatorHistoryElements: SubqueryDelegatorHistoryNodes(
                            nodes: [
                                SubqueryDelegatorHistoryItem(
                                    id: "history-2",
                                    type: unknownAction,
                                    timestampInSeconds: "1700000001",
                                    blockNumber: 43,
                                    amount: BigUInt(456)
                                )
                            ]
                        )
                    )
                ]
            )
        )
        let rewards = response.rewardHistory(for: "address-1")
        let history = response.history(for: "address-2")

        XCTAssertEqual(rewards.count, 1)
        XCTAssertEqual(rewards.first?.id, "history-1")
        XCTAssertEqual(rewards.first?.type.rawValue, SubqueryDelegationAction.reward.rawValue)
        XCTAssertEqual(rewards.first?.timestampInSeconds, "1700000000")
        XCTAssertEqual(rewards.first?.blockNumber, 42)
        XCTAssertEqual(rewards.first?.amount, BigUInt(123))

        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.type.rawValue, SubqueryDelegationAction.unknown.rawValue)
        XCTAssertEqual(history.first?.blockNumber, 43)
        XCTAssertEqual(history.first?.amount, BigUInt(456))
        XCTAssertTrue(response.rewardHistory(for: "missing").isEmpty)
        XCTAssertTrue(response.history(for: "missing").isEmpty)
        XCTAssertNil(history.first?.type.title(locale: Locale(identifier: "en_US_POSIX")))
    }

    func testSubqueryStakeChangeData_whenJsonValid_thenMapsFieldsAndLocalizedTitles() {
        let locale = Locale(identifier: "en_US_POSIX")
        let json = JSON.dictionaryValue([
            "id": .stringValue("event-1"),
            "timestamp": .stringValue("1700000008"),
            "address": .stringValue("address"),
            "amount": .stringValue("123"),
            "accumulatedAmount": .stringValue("456"),
            "type": .stringValue("bonded")
        ])
        let invalidJson = JSON.dictionaryValue([
            "id": .stringValue("event-2"),
            "timestamp": .stringValue("not-a-timestamp")
        ])

        let change = SubqueryStakeChangeData(from: json)

        XCTAssertEqual(change?.eventId, "event-1")
        XCTAssertEqual(change?.timestamp, 1_700_000_008)
        XCTAssertEqual(change?.address, "address")
        XCTAssertEqual(change?.amount, BigUInt(123))
        XCTAssertEqual(change?.accumulatedAmount, BigUInt(456))
        XCTAssertEqual(change?.type, .bonded)
        XCTAssertNil(SubqueryStakeChangeData(from: invalidJson))
        XCTAssertNil(SubqueryStakeChangeData(from: nil))

        XCTAssertFalse(SubqueryStakeChangeData.SubqueryStakeChangeType.bonded.title(for: locale).isEmpty)
        XCTAssertFalse(SubqueryStakeChangeData.SubqueryStakeChangeType.unbonded.title(for: locale).isEmpty)
        XCTAssertFalse(SubqueryStakeChangeData.SubqueryStakeChangeType.rewarded.title(for: locale).isEmpty)
        XCTAssertFalse(SubqueryStakeChangeData.SubqueryStakeChangeType.slashed.title(for: locale).isEmpty)
    }

    func testPagedKeysRequest_whenEncoded_thenUsesJsonRpcArrayShape() throws {
        let defaultRequest = PagedKeysRequest(key: "0x1234")
        let offsetRequest = PagedKeysRequest(key: "0xabcd", count: 25, offset: "0xbeef")

        let defaultJson = try XCTUnwrap(jsonFragment(from: defaultRequest) as? [Any])
        let offsetJson = try XCTUnwrap(jsonFragment(from: offsetRequest) as? [Any])

        XCTAssertEqual(defaultJson.count, 2)
        XCTAssertEqual(defaultJson[0] as? String, "0x1234")
        XCTAssertEqual(defaultJson[1] as? Int, 1000)
        XCTAssertEqual(offsetJson.count, 3)
        XCTAssertEqual(offsetJson[0] as? String, "0xabcd")
        XCTAssertEqual(offsetJson[1] as? Int, 25)
        XCTAssertEqual(offsetJson[2] as? String, "0xbeef")
    }

    func testEventCodingPath_whenStaticPathsQueried_thenMatchesExpectedRuntimeEvents() {
        XCTAssertEqual(EventCodingPath.extrisicSuccess.moduleName, "System")
        XCTAssertEqual(EventCodingPath.extrisicSuccess.eventName, "ExtrinsicSuccess")
        XCTAssertEqual(EventCodingPath.extrinsicFailed, EventCodingPath(moduleName: "System", eventName: "ExtrinsicFailed"))
        XCTAssertEqual(EventCodingPath.balanceDeposit, EventCodingPath(moduleName: "Balances", eventName: "Deposit"))
        XCTAssertEqual(EventCodingPath.treasuryDeposit, EventCodingPath(moduleName: "Treasury", eventName: "Deposit"))
        XCTAssertNotEqual(EventCodingPath.balanceDeposit, EventCodingPath.treasuryDeposit)
    }

    func testMediaType_whenUrlExtensionKnownOrMissingFileUnknown_thenClassifiesAndCaches() async throws {
        MediaTypeCache.shared.cache.removeAll()

        let imageUrl = URL(fileURLWithPath: "/tmp/test-image.jpg")
        let videoUrl = URL(fileURLWithPath: "/tmp/test-video.mov")
        let gifUrl = URL(fileURLWithPath: "/tmp/test-animation.gif")
        let unknownUrl = URL(fileURLWithPath: "/tmp/test-document.unknown")

        try await assertMediaType(.image, for: imageUrl)
        try await assertMediaType(.video, for: videoUrl)
        try await assertMediaType(.gif, for: gifUrl)

        XCTAssertEqual(MediaTypeCache.shared.cache.count, 3)
        try assertCachedMediaType(.image, for: imageUrl)
        try assertCachedMediaType(.video, for: videoUrl)
        try assertCachedMediaType(.gif, for: gifUrl)

        let unknownMediaType = await MediaType.mediaType(from: unknownUrl)

        XCTAssertNil(unknownMediaType)
        XCTAssertNil(MediaTypeCache.shared.cache[unknownUrl])
    }

    func testAmountInputViewModel_whenEditingAmount_thenFormatsValidValuesAndNotifiesObservers() throws {
        let formatter = makeAmountInputFormatter()
        let observer = AmountInputObserver()
        let model = AmountInputViewModel(
            symbol: "DOT",
            amount: nil,
            formatter: formatter,
            inputLocale: Locale(identifier: "fr_FR"),
            precision: 2
        )

        model.observable.add(observer: observer)
        model.observable.add(observer: observer)

        XCTAssertEqual(model.symbol, "DOT")
        XCTAssertEqual(model.displayAmount, "")
        XCTAssertNil(model.decimalAmount)
        XCTAssertFalse(model.isValid)
        XCTAssertEqual(model.observable.observers.count, 1)

        XCTAssertFalse(model.didReceiveReplacement("1", for: NSRange(location: model.displayAmount.count, length: 0)))
        XCTAssertEqual(model.displayAmount, "1")
        XCTAssertEqual(model.decimalAmount, Decimal(1))
        XCTAssertTrue(model.isValid)
        XCTAssertEqual(observer.changeCount, 1)

        XCTAssertFalse(model.didReceiveReplacement(",", for: NSRange(location: model.displayAmount.count, length: 0)))
        XCTAssertEqual(model.displayAmount, "1.")
        XCTAssertNil(model.decimalAmount)

        XCTAssertFalse(model.didReceiveReplacement("20", for: NSRange(location: model.displayAmount.count, length: 0)))
        XCTAssertEqual(model.displayAmount, "1.20")
        XCTAssertEqual(model.decimalAmount, Decimal(string: "1.20", locale: formatter.locale))

        XCTAssertFalse(model.didReceiveReplacement("3", for: NSRange(location: model.displayAmount.count, length: 0)))
        XCTAssertEqual(model.displayAmount, "1.20")

        model.didUpdateAmount(to: Decimal(string: "7.5")!)

        XCTAssertEqual(model.displayAmount, "7.5")
        XCTAssertEqual(model.decimalAmount, Decimal(string: "7.5", locale: formatter.locale))

        model.observable.remove(observer: observer)
        XCTAssertTrue(model.observable.observers.isEmpty)
    }

    func testAmountInputViewModel_whenGroupingOrInvalidInputProvided_thenNormalizesOrKeepsPreviousValue() {
        let formatter = makeAmountInputFormatter()
        let model = AmountInputViewModel(
            symbol: "DOT",
            amount: nil,
            formatter: formatter,
            inputLocale: Locale(identifier: "en_US"),
            precision: 0
        )

        XCTAssertFalse(model.didReceiveReplacement("1,234", for: NSRange(location: 0, length: 1)))
        XCTAssertEqual(model.displayAmount, "1,234")
        XCTAssertEqual(model.decimalAmount, Decimal(1234))
        XCTAssertTrue(model.isValid)

        XCTAssertFalse(model.didReceiveReplacement(".5", for: NSRange(location: model.displayAmount.count, length: 0)))
        XCTAssertEqual(model.displayAmount, "1,234")

        XCTAssertFalse(model.didReceiveReplacement("abc", for: NSRange(location: model.displayAmount.count, length: 0)))
        XCTAssertEqual(model.displayAmount, "1,234")

        let initializedModel = AmountInputViewModel(
            symbol: "DOT",
            amount: Decimal(42),
            formatter: formatter,
            precision: 2
        )

        XCTAssertEqual(initializedModel.displayAmount, "42")
    }

    func testTimeIntervalAndStringHelpers_whenQueried_thenReturnExpectedDerivedValues() {
        let locale = Locale(identifier: "en_US_POSIX")
        let font = UIFont.systemFont(ofSize: 12)
        let interval = TimeInterval(172_800)

        XCTAssertEqual(TimeInterval.secondsInHour, 3600)
        XCTAssertEqual(TimeInterval.secondsInDay, 86400)
        XCTAssertEqual(TimeInterval.secondsInWeek, 604_800)
        XCTAssertEqual(TimeInterval.secondsInMonth, 18_144_000)
        XCTAssertEqual(TimeInterval(1.5).milliseconds, 1500)
        XCTAssertEqual(TimeInterval(1500).seconds, 1.5)
        XCTAssertEqual(interval.daysFromSeconds, 2)
        XCTAssertEqual(interval.hoursFromSeconds, 48)
        XCTAssertEqual(TimeInterval(3600).intervalsInDay, 24)
        XCTAssertEqual(TimeInterval(0).intervalsInDay, 0)
        XCTAssertFalse(interval.readableValue(locale: locale).isEmpty)
        XCTAssertEqual(interval.localizedReadableValue().value(for: locale), interval.readableValue(locale: locale))

        let oldReferenceTime = Date().timeIntervalSinceReferenceDate - 10
        let currentReferenceTime = Date().timeIntervalSinceReferenceDate
        XCTAssertTrue(oldReferenceTime.hasPassed(since: 1))
        XCTAssertFalse(currentReferenceTime.hasPassed(since: 100))

        XCTAssertEqual(String.returnKey, "\n")
        XCTAssertEqual("fearless".underlined.string, "fearless")
        XCTAssertGreaterThan("fearless".widthOfString(usingFont: font), 0)
        XCTAssertGreaterThan("fearless".heightOfString(usingFont: font), 0)
        XCTAssertGreaterThan("fearless".sizeOfString(usingFont: font).width, 0)
        XCTAssertGreaterThan("fearless wallet".height(withConstrainedWidth: 32, font: font), 0)
    }

    func testDebounceVariants_whenCalledRepeatedly_thenExecutesOnlyLastInvocation() {
        let queue = DispatchQueue(label: "jp.co.soramitsu.fearless.tests.debounce")
        let lock = NSLock()
        let fulfillment = expectation(description: "Debounce actions executed")
        fulfillment.expectedFulfillmentCount = 3
        fulfillment.assertForOverFulfill = true

        var zeroArgCount = 0
        var oneArgValues: [Int] = []
        var twoArgValues: [(String, Int)] = []

        let zeroArgDebounced = debounce(delay: .milliseconds(40), queue: queue) {
            lock.with { zeroArgCount += 1 }
            fulfillment.fulfill()
        }

        let oneArgDebounced = debounce1(delay: .milliseconds(40), queue: queue) { (value: Int) in
            lock.with { oneArgValues.append(value) }
            fulfillment.fulfill()
        }

        let twoArgDebounced = debounce2(delay: .milliseconds(40), queue: queue) { (key: String, value: Int) in
            lock.with { twoArgValues.append((key, value)) }
            fulfillment.fulfill()
        }

        zeroArgDebounced()
        zeroArgDebounced()

        oneArgDebounced(1)
        oneArgDebounced(2)

        twoArgDebounced("first", 1)
        twoArgDebounced("last", 2)

        wait(for: [fulfillment], timeout: Constants.defaultExpectationDuration)

        lock.with {
            XCTAssertEqual(zeroArgCount, 1)
            XCTAssertEqual(oneArgValues, [2])
            XCTAssertEqual(twoArgValues.map { "\($0.0):\($0.1)" }, ["last:2"])
        }
    }

    func testThrottleVariants_whenCalledRepeatedly_thenExecutesImmediatelyAndThrottlesNextInvocation() {
        let queue = DispatchQueue(label: "jp.co.soramitsu.fearless.tests.throttle")
        let lock = NSLock()
        let firstBatch = expectation(description: "Initial throttle actions executed")
        firstBatch.expectedFulfillmentCount = 3
        firstBatch.assertForOverFulfill = true

        let secondBatch = expectation(description: "Delayed throttle actions executed")
        secondBatch.expectedFulfillmentCount = 3
        secondBatch.assertForOverFulfill = true

        var zeroArgCount = 0
        var oneArgValues: [Int] = []
        var twoArgValues: [(String, Int)] = []

        let zeroArgThrottled = throttle(delay: 0.08, queue: queue) {
            let count = lock.with { () -> Int in
                zeroArgCount += 1
                return zeroArgCount
            }

            count == 1 ? firstBatch.fulfill() : secondBatch.fulfill()
        }

        let oneArgThrottled = throttle1(delay: 0.08, queue: queue) { (value: Int) in
            let count = lock.with { () -> Int in
                oneArgValues.append(value)
                return oneArgValues.count
            }

            count == 1 ? firstBatch.fulfill() : secondBatch.fulfill()
        }

        let twoArgThrottled = throttle2(delay: 0.08, queue: queue) { (key: String, value: Int) in
            let count = lock.with { () -> Int in
                twoArgValues.append((key, value))
                return twoArgValues.count
            }

            count == 1 ? firstBatch.fulfill() : secondBatch.fulfill()
        }

        zeroArgThrottled()
        zeroArgThrottled()

        oneArgThrottled(1)
        oneArgThrottled(99)

        twoArgThrottled("first", 1)
        twoArgThrottled("ignored", 99)

        wait(for: [firstBatch], timeout: Constants.defaultExpectationDuration)

        zeroArgThrottled()
        zeroArgThrottled()

        oneArgThrottled(2)
        oneArgThrottled(999)

        twoArgThrottled("second", 2)
        twoArgThrottled("ignored", 999)

        wait(for: [secondBatch], timeout: Constants.defaultExpectationDuration)

        lock.with {
            XCTAssertEqual(zeroArgCount, 2)
            XCTAssertEqual(oneArgValues, [1, 2])
            XCTAssertEqual(twoArgValues.map { "\($0.0):\($0.1)" }, ["first:1", "second:2"])
        }
    }

    func testDatedHistoryResponses_whenDecoded_thenExposePositiveTimestampOrZeroWhenMissing() throws {
        let timestamp = "2024-01-02T03:04:05.000Z"
        let firePayload = """
        {"error":false,"message":"ok","data":{"count":1,"transactions":[{"createdAt":"\(timestamp)","value":"1","gas":"2","gasPrice":"3"}]}}
        """
        let alchemyPayload = """
        {"transfers":[{"blockNum":"0x1","uniqueId":"u","hash":"h","from":"a","to":"b","value":1.5,"asset":"ETH","category":"external","metadata":{"blockTimestamp":"\(timestamp)"}}]}
        """
        let alchemyWithoutMetadataPayload = """
        {"blockNum":"0x1","uniqueId":"u","hash":"h","from":"a","to":"b","value":1.5,"asset":"ETH","category":"external","metadata":null}
        """

        let fire = try JSONDecoder().decode(FireHistoryResponse.self, from: data(from: firePayload))
        let alchemy = try JSONDecoder().decode(AlchemyHistory.self, from: data(from: alchemyPayload))
        let alchemyWithoutMetadata = try JSONDecoder().decode(
            AlchemyHistoryElement.self,
            from: data(from: alchemyWithoutMetadataPayload)
        )

        XCTAssertEqual(fire.data?.count, 1)
        XCTAssertEqual(fire.data?.transactions.first?.value, BigUInt(1))
        XCTAssertEqual(fire.data?.transactions.first?.gasPrice, BigUInt(3))
        XCTAssertGreaterThan(fire.data?.transactions.first?.timestampInSeconds ?? 0, 0)
        XCTAssertEqual(alchemy.transfers.first?.hash, "h")
        XCTAssertGreaterThan(alchemy.transfers.first?.timestampInSeconds ?? 0, 0)
        XCTAssertEqual(alchemyWithoutMetadata.timestampInSeconds, 0)
    }

    func testEvmHistoryMappers_whenResponsesDecoded_thenMapTransactionsConsistently() throws {
        let address = "0xwallet"
        let asset = makeHistoryAsset()
        let chain = makeChain(chainId: "evm-chain", assets: [asset])
        let timestamp = "2024-01-02T03:04:05.000Z"
        let alchemyPayload = """
        {"blockNum":"0x1","uniqueId":"alchemy-id","hash":"alchemy-hash","from":"\(address)","to":"0xpeer","value":1.5,"asset":"ETH","category":"external","metadata":{"blockTimestamp":"\(timestamp)"}}
        """
        let etherscanPayload = """
        {"timeStamp":"1700000003","hash":"etherscan-hash","from":"\(address)","to":"0xpeer","contractAddress":"0xtoken","value":"12345","gas":"9","gasPrice":"2","gasUsed":"3"}
        """
        let firePayload = """
        {"createdAt":"\(timestamp)","hash":"fire-hash","fromAddress":"\(address)","toAddress":"0xpeer","value":"12345","gas":"2","gasPrice":"3"}
        """
        let kaiaPayload = """
        {"createdAt":1700000004,"txHash":"kaia-hash","fromAddress":"\(address)","toAddress":"0xpeer","amount":"12345","txFee":"7"}
        """
        let viscanPayload = """
        {"timestamp":1700000005,"hash":"viscan-hash","from":"0xpeer","to":"\(address)","contractAddress":"0xtoken","value":"12345","fee":1.25}
        """
        let zchainPayload = """
        {"ti":1700000006,"h":"zchain-hash","v":"12345","tf":"8","f":{"a":"\(address)"},"t":{"a":"0xpeer"}}
        """
        let oklinkPayload = """
        {
          "txId":"oklink-hash",
          "methodId":"0x",
          "blockHash":"block",
          "height":"1",
          "transactionTime":"1700000007000",
          "from":"\(address)",
          "to":"0xpeer",
          "isFromContract":false,
          "isToContract":false,
          "amount":"12.5",
          "transactionSymbol":"XOR",
          "txFee":"0.01",
          "state":"success",
          "tokenId":"",
          "tokenContractAddress":"0xtoken",
          "challengeStatus":"",
          "l1OriginHash":""
        }
        """
        let blockscoutPayload = """
        {
          "timestamp":"\(timestamp)",
          "from":{"hash":"\(address)"},
          "to":{"hash":"0xpeer"},
          "fee":{"type":"actual","value":"6"},
          "value":"12345",
          "hash":null,
          "txHash":"blockscout-hash"
        }
        """

        let alchemy = try JSONDecoder().decode(AlchemyHistoryElement.self, from: data(from: alchemyPayload))
        let etherscan = try JSONDecoder().decode(EtherscanHistoryElement.self, from: data(from: etherscanPayload))
        let fire = try JSONDecoder().decode(FireHistoryTransaction.self, from: data(from: firePayload))
        let kaia = try JSONDecoder().decode(KaiaHistoryTransaction.self, from: data(from: kaiaPayload))
        let viscan = try JSONDecoder().decode(ViscanHistoryElement.self, from: data(from: viscanPayload))
        let zchain = try JSONDecoder().decode(ZChainHistoryElement.self, from: data(from: zchainPayload))
        let oklink = try JSONDecoder().decode(OklinkTransactionItem.self, from: data(from: oklinkPayload))
        let blockscout = try JSONDecoder().decode(BlockscoutItem.self, from: data(from: blockscoutPayload))

        let alchemyTransaction = AssetTransactionData.createTransaction(from: alchemy, address: address)
        let etherscanTransaction = AssetTransactionData.createTransaction(
            from: etherscan,
            address: address,
            chain: chain,
            asset: asset
        )
        let fireTransaction = AssetTransactionData.createTransaction(
            from: fire,
            address: address,
            chain: chain,
            asset: asset
        )
        let kaiaTransaction = AssetTransactionData.createTransaction(
            from: kaia,
            address: address,
            chain: chain,
            asset: asset
        )
        let viscanTransaction = AssetTransactionData.createTransaction(
            from: viscan,
            address: address,
            chain: chain,
            asset: asset
        )
        let zchainTransaction = AssetTransactionData.createTransaction(
            from: zchain,
            address: address,
            chain: chain,
            asset: asset
        )
        let oklinkTransaction = AssetTransactionData.createTransaction(
            from: oklink,
            address: address,
            chain: chain,
            asset: asset
        )
        let blockscoutTransaction = AssetTransactionData.createTransaction(
            from: blockscout,
            address: address,
            chain: chain,
            asset: asset
        )

        XCTAssertEqual(alchemyTransaction.transactionId, "alchemy-id")
        XCTAssertEqual(alchemyTransaction.assetId, "ETH")
        XCTAssertEqual(alchemyTransaction.peerName, "0xpeer")
        XCTAssertEqual(alchemyTransaction.amount, AmountDecimal(value: decimal("1.5")))
        XCTAssertEqual(alchemyTransaction.type, TransactionType.outgoing.rawValue)
        XCTAssertGreaterThan(alchemyTransaction.timestamp, 0)

        XCTAssertEqual(etherscanTransaction.transactionId, "etherscan-hash")
        XCTAssertEqual(etherscanTransaction.assetId, "0xtoken")
        XCTAssertEqual(etherscanTransaction.amount, AmountDecimal(value: decimal("123.45")))
        XCTAssertEqual(etherscanTransaction.fees.first?.amount, AmountDecimal(value: decimal("0.06")))
        XCTAssertEqual(etherscanTransaction.timestamp, 1_700_000_003)
        XCTAssertEqual(etherscanTransaction.type, TransactionType.outgoing.rawValue)

        XCTAssertEqual(fireTransaction.transactionId, "fire-hash")
        XCTAssertEqual(fireTransaction.peerName, "0xpeer")
        XCTAssertEqual(fireTransaction.amount, AmountDecimal(value: decimal("123.45")))
        XCTAssertEqual(fireTransaction.fees.first?.amount, AmountDecimal(value: decimal("0.06")))
        XCTAssertEqual(fireTransaction.type, TransactionType.outgoing.rawValue)

        XCTAssertEqual(kaiaTransaction.transactionId, "kaia-hash")
        XCTAssertEqual(kaiaTransaction.amount, AmountDecimal(value: decimal("123.45")))
        XCTAssertEqual(kaiaTransaction.fees.first?.amount, AmountDecimal(value: decimal("0.07")))
        XCTAssertEqual(kaiaTransaction.timestamp, 1_700_000_004)

        XCTAssertEqual(viscanTransaction.transactionId, "viscan-hash")
        XCTAssertEqual(viscanTransaction.peerName, "0xpeer")
        XCTAssertEqual(viscanTransaction.amount, AmountDecimal(value: decimal("123.45")))
        XCTAssertEqual(viscanTransaction.fees.first?.amount, AmountDecimal(value: decimal("1.25")))
        XCTAssertEqual(viscanTransaction.type, TransactionType.incoming.rawValue)

        XCTAssertEqual(zchainTransaction.transactionId, "zchain-hash")
        XCTAssertEqual(zchainTransaction.amount, AmountDecimal(value: decimal("123.45")))
        XCTAssertEqual(zchainTransaction.fees.first?.amount, AmountDecimal(value: decimal("0.08")))
        XCTAssertEqual(zchainTransaction.timestamp, 1_700_000_006)

        XCTAssertEqual(oklinkTransaction.transactionId, "oklink-hash")
        XCTAssertEqual(oklinkTransaction.assetId, "0xtoken")
        XCTAssertEqual(oklinkTransaction.amount, AmountDecimal(value: decimal("12.5")))
        XCTAssertEqual(oklinkTransaction.fees.first?.amount, AmountDecimal(value: decimal("0.01")))
        XCTAssertEqual(oklinkTransaction.timestamp, 1_700_000_007)

        XCTAssertEqual(blockscoutTransaction.transactionId, "blockscout-hash")
        XCTAssertEqual(blockscoutTransaction.amount, AmountDecimal(value: decimal("123.45")))
        XCTAssertEqual(blockscoutTransaction.fees.first?.amount, AmountDecimal(value: decimal("0.06")))
        XCTAssertEqual(blockscoutTransaction.type, TransactionType.outgoing.rawValue)
        XCTAssertGreaterThan(blockscoutTransaction.timestamp, 0)
    }

    func testSoraSubsquidHistoryMapper_whenMethodsDecoded_thenMapsSpecializedTransactionTypes() throws {
        let address = "sender"
        let asset = makeHistoryAsset()
        let chain = makeChain(chainId: "sora-chain", assets: [asset])
        let payload = """
        {
          "historyElementsConnection": {
            "edges": [
              {
                "node": {
                  "id": "reward-id",
                  "address": "stash",
                  "method": "rewarded",
                  "module": "staking",
                  "networkFee": "1",
                  "timestamp": 1779398268000,
                  "execution": { "success": true },
                  "data": { "stash": "stash", "amount": "10.5", "era": 7 }
                }
              },
              {
                "node": {
                  "id": "transfer-id",
                  "address": "sender",
                  "method": "transfer",
                  "module": "assets",
                  "networkFee": "2",
                  "timestamp": 1779398269000,
                  "execution": { "success": false },
                  "data": { "from": "sender", "to": "receiver", "amount": "11.5", "assetId": "xor" }
                }
              },
              {
                "node": {
                  "id": "swap-id",
                  "address": "stash",
                  "method": "swap",
                  "module": "liquidityProxy",
                  "networkFee": "3",
                  "timestamp": 1779398270000,
                  "execution": { "success": false },
                  "data": {
                    "stash": "stash",
                    "targetAssetId": "target",
                    "targetAssetAmount": "12.5",
                    "baseAssetId": "base",
                    "baseAssetAmount": "13.5"
                  }
                }
              },
              {
                "node": {
                  "id": "bridge-id",
                  "address": "stash",
                  "method": "transferToSidechain",
                  "module": "ethBridge",
                  "networkFee": "4",
                  "timestamp": 1779398271000,
                  "execution": { "success": true },
                  "data": { "stash": "stash", "amount": "14.5" }
                }
              },
              {
                "node": {
                  "id": "extrinsic-id",
                  "address": "caller",
                  "method": "remark",
                  "module": "system",
                  "networkFee": "5",
                  "timestamp": 1779398272,
                  "execution": { "success": false },
                  "data": { "to": "receiver", "assetId": "xor" }
                }
              },
              {
                "node": {
                  "id": "incoming-transfer-id",
                  "address": "sender",
                  "method": "transfer",
                  "module": "assets",
                  "networkFee": "bad",
                  "timestamp": 1779398273000,
                  "execution": { "success": true },
                  "data": { "from": "receiver", "to": "sender", "amount": "bad" }
                }
              },
              {
                "node": {
                  "id": "reward-without-era-id",
                  "address": "stash",
                  "method": "rewarded",
                  "module": "staking",
                  "timestamp": 1779398274000,
                  "execution": { "success": false },
                  "data": { "stash": "stash", "amount": "bad" }
                }
              },
              {
                "node": {
                  "id": "default-extrinsic-id",
                  "method": "remark",
                  "module": "system",
                  "timestamp": 1779398275000
                }
              }
            ],
            "totalCount": 8
          }
        }
        """

        let response = try JSONDecoder().decode(
            SoraSubsquidHistoryConnectionResponse.self,
            from: data(from: payload)
        )
        let transactions = response.historyElementsConnection.edges.map { edge in
            AssetTransactionData.createTransaction(
                from: edge.node,
                address: address,
                chain: chain,
                asset: asset
            )
        }

        XCTAssertEqual(transactions.map(\.transactionId), [
            "reward-id",
            "transfer-id",
            "swap-id",
            "bridge-id",
            "extrinsic-id",
            "incoming-transfer-id",
            "reward-without-era-id",
            "default-extrinsic-id"
        ])
        XCTAssertEqual(transactions[0].status, .commited)
        XCTAssertEqual(transactions[0].peerName, "stash")
        XCTAssertEqual(transactions[0].details, "7")
        XCTAssertEqual(transactions[0].amount, AmountDecimal(value: decimal("10.5")))
        XCTAssertEqual(transactions[0].type, TransactionType.reward.rawValue)
        XCTAssertEqual(transactions[0].fees.first?.amount, AmountDecimal(value: decimal("0.01")))

        XCTAssertEqual(transactions[1].status, .rejected)
        XCTAssertEqual(transactions[1].assetId, "xor")
        XCTAssertEqual(transactions[1].peerName, "receiver")
        XCTAssertEqual(transactions[1].amount, AmountDecimal(value: decimal("11.5")))
        XCTAssertEqual(transactions[1].type, TransactionType.outgoing.rawValue)
        XCTAssertEqual(transactions[1].timestamp, 1_779_398_269)

        XCTAssertEqual(transactions[2].status, .commited)
        XCTAssertEqual(transactions[2].assetId, "target")
        XCTAssertEqual(transactions[2].peerId, "base")
        XCTAssertEqual(transactions[2].details, "13.5")
        XCTAssertEqual(transactions[2].amount, AmountDecimal(value: decimal("12.5")))
        XCTAssertEqual(transactions[2].type, TransactionType.swap.rawValue)

        XCTAssertEqual(transactions[3].status, .commited)
        XCTAssertEqual(transactions[3].peerName, "stash")
        XCTAssertEqual(transactions[3].amount, AmountDecimal(value: decimal("14.5")))
        XCTAssertEqual(transactions[3].type, TransactionType.bridge.rawValue)

        XCTAssertEqual(transactions[4].status, .commited)
        XCTAssertEqual(transactions[4].peerId, "caller")
        XCTAssertEqual(transactions[4].peerFirstName, "system")
        XCTAssertEqual(transactions[4].peerLastName, "remark")
        XCTAssertEqual(transactions[4].peerName, "receiver")
        XCTAssertEqual(transactions[4].amount, AmountDecimal(value: decimal("0.05")))
        XCTAssertEqual(transactions[4].type, TransactionType.extrinsic.rawValue)

        XCTAssertEqual(transactions[5].status, .commited)
        XCTAssertEqual(transactions[5].assetId, "")
        XCTAssertEqual(transactions[5].peerName, "receiver")
        XCTAssertEqual(transactions[5].amount, AmountDecimal(value: 0))
        XCTAssertEqual(transactions[5].fees.first?.amount, AmountDecimal(value: 0))
        XCTAssertEqual(transactions[5].type, TransactionType.incoming.rawValue)

        XCTAssertEqual(transactions[6].status, .rejected)
        XCTAssertEqual(transactions[6].peerName, "stash")
        XCTAssertEqual(transactions[6].details, "")
        XCTAssertEqual(transactions[6].amount, AmountDecimal(value: 0))
        XCTAssertEqual(transactions[6].type, TransactionType.reward.rawValue)

        XCTAssertEqual(transactions[7].status, .commited)
        XCTAssertEqual(transactions[7].assetId, "")
        XCTAssertEqual(transactions[7].peerId, "")
        XCTAssertEqual(transactions[7].peerFirstName, "system")
        XCTAssertEqual(transactions[7].peerLastName, "remark")
        XCTAssertNil(transactions[7].peerName)
        XCTAssertEqual(transactions[7].amount, AmountDecimal(value: 0))
        XCTAssertEqual(transactions[7].type, TransactionType.extrinsic.rawValue)
    }

    func testSubsquidAndSubqueryHistoryMappers_whenDecoded_thenMapTransfersRewardsExtrinsicsAndUnknowns() throws {
        let address = "sender"
        let asset = makeHistoryAsset()
        let chain = makeChain(chainId: "substrate-chain", assets: [asset])
        let subsquidPayload = """
        {
          "historyElements": [
            {
              "id": "subsquid-transfer",
              "timestamp": "1700000005000",
              "address": "sender",
              "extrinsicHash": "transfer-hash",
              "transfer": {
                "amount": "12345",
                "to": "receiver",
                "from": "sender",
                "fee": "6",
                "success": true
              }
            },
            {
              "id": "subsquid-reward",
              "timestamp": "1700000006000",
              "address": "stash",
              "reward": {
                "amount": "700",
                "isReward": false,
                "era": 9,
                "validator": "validator"
              }
            },
            {
              "id": "subsquid-extrinsic",
              "timestamp": "1700000007000",
              "address": "caller",
              "extrinsic": {
                "hash": "extrinsic-hash",
                "module": "staking",
                "call": "bond",
                "fee": "8",
                "success": false
              }
            },
            {
              "id": "subsquid-unknown",
              "timestamp": "1700000008000",
              "address": "caller"
            }
          ]
        }
        """
        let arrowsquidPayload = """
        {
          "historyElements": [
            {
              "id": "arrow-transfer",
              "timestamp": 1700000009,
              "address": "sender",
              "extrinsicHash": "arrow-transfer-hash",
              "success": false,
              "transfer": {
                "amount": "900",
                "to": "receiver",
                "from": "sender",
                "fee": "4"
              }
            },
            {
              "id": "arrow-reward",
              "timestamp": 1700000010,
              "address": "stash",
              "extrinsicHash": "arrow-reward-hash",
              "success": true,
              "reward": {
                "amount": "1000",
                "stash": "stash",
                "era": 10,
                "validator": "validator"
              }
            },
            {
              "id": "arrow-unknown",
              "timestamp": 1700000011,
              "address": "caller",
              "success": true
            }
          ]
        }
        """
        let subqueryPayload = """
        {
          "historyElements": {
            "pageInfo": { "hasNextPage": false },
            "nodes": [
              {
                "id": "subquery-transfer",
                "timestamp": "1700000012",
                "address": "sender",
                "transfer": {
                  "amount": "1100",
                  "to": "receiver",
                  "from": "sender",
                  "fee": "5",
                  "success": true
                }
              },
              {
                "id": "subquery-reward",
                "timestamp": "1700000013",
                "address": "stash",
                "reward": {
                  "amount": "1200",
                  "isReward": true,
                  "era": 11,
                  "validator": "validator"
                }
              },
              {
                "id": "subquery-extrinsic",
                "timestamp": "1700000014",
                "address": "caller",
                "extrinsic": {
                  "hash": "subquery-extrinsic-hash",
                  "module": "balances",
                  "call": "transfer",
                  "fee": "7",
                  "success": true
                }
              },
              {
                "id": "subquery-unknown",
                "timestamp": "1700000015",
                "address": "caller"
              }
            ]
          }
        }
        """

        let subsquid = try JSONDecoder().decode(SubsquidHistoryResponse.self, from: data(from: subsquidPayload))
        let arrowsquid = try JSONDecoder().decode(ArrowsquidHistoryResponse.self, from: data(from: arrowsquidPayload))
        let subquery = try JSONDecoder().decode(SubqueryHistoryData.self, from: data(from: subqueryPayload))
        let subsquidTransactions = subsquid.historyElements.map { item in
            AssetTransactionData.createTransaction(from: item, address: address, chain: chain, asset: asset)
        }
        let arrowsquidTransactions = arrowsquid.historyElements.map { item in
            AssetTransactionData.createTransaction(from: item, address: address, chain: chain, asset: asset)
        }
        let subqueryTransactions = subquery.historyElements.nodes.map { item in
            AssetTransactionData.createTransaction(from: item, address: address, chain: chain, asset: asset)
        }

        XCTAssertEqual(subsquid.data.count, 4)
        XCTAssertEqual(subsquid.historyElements.map(\.itemTimestamp), [
            1_700_000_005,
            1_700_000_006,
            1_700_000_007,
            1_700_000_008
        ])
        XCTAssertEqual(subsquid.historyElements[0].label.rawValue, WalletRemoteHistorySourceLabel.transfers.rawValue)
        XCTAssertEqual(subsquid.historyElements[1].label.rawValue, WalletRemoteHistorySourceLabel.rewards.rawValue)
        XCTAssertEqual(subsquid.historyElements[2].label.rawValue, WalletRemoteHistorySourceLabel.extrinsics.rawValue)
        XCTAssertEqual(subsquid.historyElements[1].rewardInfo?.amount, "700")
        XCTAssertEqual(arrowsquid.data.count, 3)
        XCTAssertEqual(arrowsquid.historyElements[0].itemTimestamp, 1_700_000_009)
        XCTAssertEqual(arrowsquid.historyElements[0].label.rawValue, WalletRemoteHistorySourceLabel.transfers.rawValue)
        XCTAssertEqual(arrowsquid.historyElements[1].label.rawValue, WalletRemoteHistorySourceLabel.rewards.rawValue)
        XCTAssertEqual(arrowsquid.historyElements[1].rewardInfo?.amount, "1000")
        XCTAssertNil(subquery.historyElements.nodes[0].extrinsicHash)
        XCTAssertEqual(subquery.historyElements.nodes[0].itemBlockNumber, 0)
        XCTAssertEqual(subquery.historyElements.nodes[0].itemExtrinsicIndex, 0)
        XCTAssertEqual(subquery.historyElements.nodes[0].itemTimestamp, 1_700_000_012)
        XCTAssertEqual(
            subquery.historyElements.nodes[0]
                .createTransactionForAddress(address, chain: chain, asset: asset)
                .transactionId,
            "subquery-transfer"
        )

        XCTAssertEqual(subsquidTransactions[0].transactionId, "transfer-hash")
        XCTAssertEqual(subsquidTransactions[0].status, .commited)
        XCTAssertEqual(subsquidTransactions[0].peerName, "receiver")
        XCTAssertEqual(subsquidTransactions[0].amount, AmountDecimal(value: decimal("123.45")))
        XCTAssertEqual(subsquidTransactions[0].fees.first?.amount, AmountDecimal(value: decimal("0.06")))
        XCTAssertEqual(subsquidTransactions[0].type, TransactionType.outgoing.rawValue)
        XCTAssertEqual(subsquidTransactions[1].type, TransactionType.slash.rawValue)
        XCTAssertEqual(subsquidTransactions[1].peerFirstName, "validator")
        XCTAssertEqual(subsquidTransactions[1].details, "#9")
        XCTAssertEqual(subsquidTransactions[2].status, .rejected)
        XCTAssertEqual(subsquidTransactions[2].peerName, "staking bond")
        XCTAssertEqual(subsquidTransactions[2].reason, "extrinsic-hash")
        XCTAssertEqual(subsquidTransactions[3].status, .pending)
        XCTAssertEqual(subsquidTransactions[3].type, "UNKNOWN")

        XCTAssertEqual(arrowsquidTransactions[0].transactionId, "arrow-transfer-hash")
        XCTAssertEqual(arrowsquidTransactions[0].status, .rejected)
        XCTAssertEqual(arrowsquidTransactions[0].amount, AmountDecimal(value: decimal("9")))
        XCTAssertEqual(arrowsquidTransactions[0].fees.first?.amount, AmountDecimal(value: decimal("0.04")))
        XCTAssertEqual(arrowsquidTransactions[1].type, TransactionType.reward.rawValue)
        XCTAssertEqual(arrowsquidTransactions[1].details, "#10")
        XCTAssertEqual(arrowsquidTransactions[2].type, "UNKNOWN")

        XCTAssertEqual(subqueryTransactions[0].transactionId, "subquery-transfer")
        XCTAssertEqual(subqueryTransactions[0].status, .commited)
        XCTAssertEqual(subqueryTransactions[0].amount, AmountDecimal(value: decimal("11")))
        XCTAssertEqual(subqueryTransactions[0].fees.first?.amount, AmountDecimal(value: decimal("0.05")))
        XCTAssertEqual(subqueryTransactions[1].type, TransactionType.reward.rawValue)
        XCTAssertEqual(subqueryTransactions[1].amount, AmountDecimal(value: decimal("12")))
        XCTAssertEqual(subqueryTransactions[2].peerName, "balances transfer")
        XCTAssertEqual(subqueryTransactions[2].reason, "subquery-extrinsic-hash")
        XCTAssertEqual(subqueryTransactions[3].status, .pending)
        XCTAssertEqual(subqueryTransactions[3].type, "UNKNOWN")
    }

    func testLocalSubqueryHistoryMapper_whenTransactionHistoryItemsProvided_thenMapsTransfersAndExtrinsics() {
        let address = "sender"
        let asset = makeHistoryAsset()
        let chain = makeChain(chainId: "substrate-chain", assets: [asset])
        let encodedTransferCall = """
        [
          "Balances",
          [
            "transfer",
            {
              "dest": [
                "Id",
                [
                  "7", "7", "7", "7", "7", "7", "7", "7",
                  "7", "7", "7", "7", "7", "7", "7", "7",
                  "7", "7", "7", "7", "7", "7", "7", "7",
                  "7", "7", "7", "7", "7", "7", "7", "7"
                ]
              ],
              "value": "12345"
            }
          ]
        ]
        """.data(using: .utf8)
        let transferItem = TransactionHistoryItem(
            sender: address,
            receiver: "receiver",
            status: .success,
            txHash: "local-transfer",
            timestamp: 1_700_000_016,
            fee: "6",
            blockNumber: 16,
            txIndex: 1,
            callPath: .transfer,
            call: encodedTransferCall
        )
        let malformedTransferItem = TransactionHistoryItem(
            sender: "remote-sender",
            receiver: nil,
            status: .failed,
            txHash: "local-transfer-malformed",
            timestamp: 1_700_000_017,
            fee: "7",
            blockNumber: nil,
            txIndex: nil,
            callPath: .transferKeepAlive,
            call: Data([0x00])
        )
        let extrinsicItem = TransactionHistoryItem(
            sender: address,
            receiver: nil,
            status: .pending,
            txHash: "local-extrinsic",
            timestamp: 1_700_000_018,
            fee: "8",
            blockNumber: 18,
            txIndex: 2,
            callPath: .nominationPoolJoin,
            call: nil
        )

        let transfer = AssetTransactionData.createTransaction(
            from: transferItem,
            address: address,
            chain: chain,
            asset: asset
        )
        let malformedTransfer = AssetTransactionData.createTransaction(
            from: malformedTransferItem,
            address: address,
            chain: chain,
            asset: asset
        )
        let extrinsic = AssetTransactionData.createTransaction(
            from: extrinsicItem,
            address: address,
            chain: chain,
            asset: asset
        )

        XCTAssertEqual(transfer.transactionId, "local-transfer")
        XCTAssertEqual(transfer.status, .commited)
        XCTAssertEqual(transfer.peerName, "receiver")
        XCTAssertEqual(transfer.amount, AmountDecimal(value: decimal("123.45")))
        XCTAssertEqual(transfer.fees.first?.amount, AmountDecimal(value: decimal("0.06")))
        XCTAssertEqual(transfer.timestamp, 1_700_000_016)
        XCTAssertEqual(transfer.type, TransactionType.outgoing.rawValue)
        XCTAssertNil(transfer.reason)

        XCTAssertEqual(malformedTransfer.status, .rejected)
        XCTAssertEqual(malformedTransfer.peerName, "remote-sender")
        XCTAssertEqual(malformedTransfer.amount, AmountDecimal(value: 0))
        XCTAssertEqual(malformedTransfer.fees.first?.amount, AmountDecimal(value: decimal("0.07")))
        XCTAssertEqual(malformedTransfer.type, TransactionType.incoming.rawValue)

        XCTAssertEqual(extrinsic.transactionId, "local-extrinsic")
        XCTAssertEqual(extrinsic.status, .pending)
        XCTAssertEqual(extrinsic.peerId, address)
        XCTAssertEqual(extrinsic.peerFirstName, "NominationPools")
        XCTAssertEqual(extrinsic.peerLastName, "join")
        XCTAssertEqual(extrinsic.peerName, "NominationPools join")
        XCTAssertEqual(extrinsic.amount, AmountDecimal(value: decimal("0.08")))
        XCTAssertEqual(extrinsic.fees, [])
        XCTAssertEqual(extrinsic.type, TransactionType.extrinsic.rawValue)
    }

    func testGiantsquidHistoryMappers_whenDecoded_thenMapAllSupportedTransactionShapes() throws {
        let timestamp = "2024-01-02T03:04:05.000Z"
        let address = "sender"
        let asset = makeHistoryAsset()
        let chain = makeChain(chainId: "giantsquid-chain", assets: [asset])
        let responsePayload = """
        {
          "data": {
            "transfers": [
              {
                "id": "transfer-wrapper",
                "transfer": {
                  "id": "transfer-id",
                  "amount": "12345",
                  "to": { "id": "receiver" },
                  "from": { "id": "sender" },
                  "success": true,
                  "extrinsicHash": "transfer-hash",
                  "timestamp": "\(timestamp)",
                  "blockNumber": 10,
                  "type": "transfer",
                  "feeAmount": "6",
                  "signedData": { "fee": { "class": "normal", "weight": 1, "partialFee": "7" } },
                  "blockHash": "block-hash"
                }
              }
            ],
            "stakingRewards": [
              {
                "amount": "800",
                "era": 3,
                "accountId": "stash",
                "validator": "validator",
                "timestamp": "\(timestamp)",
                "extrinsicHash": "reward-hash",
                "blockNumber": 11,
                "id": "reward-id"
              }
            ],
            "bonds": [
              {
                "id": "bond-id",
                "accountId": "stash",
                "amount": "900",
                "blockNumber": 12,
                "extrinsicHash": "bond-hash",
                "success": true,
                "timestamp": "\(timestamp)",
                "type": "bond"
              }
            ],
            "slashes": [
              {
                "id": "slash-id",
                "accountId": "stash",
                "amount": "1000",
                "blockNumber": 13,
                "era": 4,
                "timestamp": "\(timestamp)"
              }
            ]
          }
        }
        """
        let extrinsicPayload = """
        {
          "id": "extrinsic-id",
          "timestamp": "\(timestamp)",
          "section": "balances",
          "method": "transfer",
          "hash": "0xhash-1",
          "status": "failed",
          "type": "call",
          "signedData": { "fee": { "class": "normal", "weight": 1, "partialFee": "11" } }
        }
        """

        let response = try JSONDecoder().decode(GiantsquidResponse.self, from: data(from: responsePayload))
        let transfer = try XCTUnwrap(response.data.history[0] as? GiantsquidTransfer)
        let reward = try XCTUnwrap(response.data.history[1] as? GiantsquidReward)
        let bond = try XCTUnwrap(response.data.history[2] as? GiantsquidBond)
        let slash = try XCTUnwrap(response.data.history[3] as? GiantsquidSlash)
        let extrinsic = try JSONDecoder().decode(GiantsquidExtrinsic.self, from: data(from: extrinsicPayload))
        let transferTransaction = AssetTransactionData.createTransaction(
            transfer: transfer,
            address: address,
            asset: asset
        )
        let rewardTransaction = AssetTransactionData.createTransaction(
            reward: reward,
            address: address,
            chain: chain,
            asset: asset
        )
        let bondTransaction = AssetTransactionData.createTransaction(
            bond: bond,
            address: address,
            chain: chain,
            asset: asset
        )
        let slashTransaction = AssetTransactionData.createTransaction(
            slash: slash,
            address: address,
            chain: chain,
            asset: asset
        )
        let extrinsicTransaction = AssetTransactionData.createTransaction(
            extrinsic: extrinsic,
            address: address,
            asset: asset
        )

        XCTAssertEqual(transferTransaction.transactionId, "transfer-id")
        XCTAssertEqual(transferTransaction.status, .commited)
        XCTAssertEqual(transferTransaction.peerName, "receiver")
        XCTAssertEqual(transferTransaction.amount, AmountDecimal(value: decimal("123.45")))
        XCTAssertEqual(transferTransaction.fees.map(\.amount), [
            AmountDecimal(value: decimal("0.06")),
            AmountDecimal(value: decimal("0.07"))
        ])
        XCTAssertEqual(transferTransaction.type, TransactionType.outgoing.rawValue)
        XCTAssertEqual(transferTransaction.context?["reefBlockHash"], "block-hash")

        XCTAssertEqual(rewardTransaction.transactionId, "reward-id")
        XCTAssertEqual(rewardTransaction.status, .commited)
        XCTAssertEqual(rewardTransaction.peerName, TransactionType.reward.rawValue)
        XCTAssertEqual(rewardTransaction.peerFirstName, "validator")
        XCTAssertEqual(rewardTransaction.details, "#3")
        XCTAssertEqual(rewardTransaction.amount, AmountDecimal(value: decimal("8")))
        XCTAssertEqual(rewardTransaction.type, TransactionType.reward.rawValue)
        XCTAssertEqual(rewardTransaction.reason, "reward-id")

        XCTAssertEqual(bondTransaction.transactionId, "bond-id")
        XCTAssertEqual(bondTransaction.peerName, TransactionType.extrinsic.rawValue)
        XCTAssertEqual(bondTransaction.peerFirstName, "stash")
        XCTAssertEqual(bondTransaction.details, "#12")
        XCTAssertEqual(bondTransaction.amount, AmountDecimal(value: decimal("9")))
        XCTAssertEqual(bondTransaction.reason, "bond-id")

        XCTAssertEqual(slashTransaction.transactionId, "slash-id")
        XCTAssertEqual(slashTransaction.peerName, TransactionType.extrinsic.rawValue)
        XCTAssertEqual(slashTransaction.peerFirstName, "stash")
        XCTAssertEqual(slashTransaction.details, "#13")
        XCTAssertEqual(slashTransaction.amount, AmountDecimal(value: decimal("10")))
        XCTAssertEqual(slashTransaction.reason, "slash-id")

        XCTAssertEqual(extrinsic.identifier, "extrinsic-id")
        XCTAssertEqual(extrinsic.extrinsicHash, "0xhash")
        XCTAssertEqual(extrinsic.itemBlockNumber, 0)
        XCTAssertEqual(extrinsic.itemExtrinsicIndex, 0)
        XCTAssertEqual(extrinsic.itemTimestamp, 1_704_164_645)
        XCTAssertEqual(extrinsic.label.rawValue, WalletRemoteHistorySourceLabel.extrinsics.rawValue)
        XCTAssertEqual(
            extrinsic.createTransactionForAddress(address, chain: chain, asset: asset),
            extrinsicTransaction
        )
        XCTAssertEqual(extrinsicTransaction.transactionId, "0xhash-1")
        XCTAssertEqual(extrinsicTransaction.status, .rejected)
        XCTAssertEqual(extrinsicTransaction.peerId, address)
        XCTAssertEqual(extrinsicTransaction.peerFirstName, "balances")
        XCTAssertEqual(extrinsicTransaction.peerLastName, "transfer")
        XCTAssertEqual(extrinsicTransaction.peerName, "balances transfer")
        XCTAssertEqual(extrinsicTransaction.amount, AmountDecimal(value: decimal("0.11")))
        XCTAssertEqual(extrinsicTransaction.fees.first?.amount, AmountDecimal(value: decimal("0.11")))
        XCTAssertEqual(extrinsicTransaction.type, TransactionType.extrinsic.rawValue)
        XCTAssertEqual(extrinsicTransaction.reason, "extrinsic-id")
    }

    func testSimpleEvents_whenAccepted_thenDispatchToMatchingVisitorMethods() {
        let visitor = EventVisitorRecorder()
        let wallet = AccountGenerator.generateMetaAccount()
        let chain = makeChain(chainId: "event-chain")
        let asset = ChainModelGenerator.generateAssetWithId("event-asset", symbol: "EVT")
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        let events: [EventProtocol] = [
            SelectedAccountChanged(account: wallet),
            PricesUpdated(),
            WalletNewTransactionInserted(),
            AccountScoreSettingsChanged(),
            WalletBalanceChanged(),
            SelectedUsernameChanged(),
            PurchaseCompleted(),
            WalletStakingInfoChanged(),
            SelectedConnectionChanged(),
            EraStakersInfoChanged(),
            WalletNameChanged(wallet: wallet),
            StakingUpdatedEvent(),
            ChainsSetupCompleted(),
            LogoutEvent(),
            ChainSyncDidStart(),
            ChainSyncDidComplete(newOrUpdatedChains: [], removedChains: []),
            ChainSyncDidFail(error: TestEventError.sample),
            ChainsUpdatedEvent(updatedChains: [chain]),
            RuntimeChainsTypesSyncCompleted(versioningMap: ["sora": Data([1, 2, 3])]),
            RuntimeSnapshotReady(chainModel: chain),
            TypeRegistryPrepared(version: 42),
            MetaAccountModelChangedEvent(account: wallet),
            WalletRemoteSubscriptionWasUpdatedEvent(chainAsset: chainAsset)
        ]

        events.forEach { $0.accept(visitor: visitor) }

        XCTAssertEqual(
            visitor.calls,
            [
                "selectedAccount:\(wallet.metaId)",
                "prices",
                "newTransaction",
                "accountScoreSettings",
                "balance",
                "selectedUsername",
                "purchase",
                "staking",
                "selectedConnection",
                "eraStakers",
                "walletName:\(wallet.metaId)",
                "stakingUpdated",
                "chainsSetup",
                "logout",
                "chainSyncStart",
                "chainSyncComplete:0:0",
                "chainSyncFail",
                "chainsUpdated:event-chain",
                "runtimeChainsTypes:sora",
                "runtimeSnapshot:event-chain",
                "typeRegistry:42",
                "metaAccount:\(wallet.metaId)",
                "remoteSubscription:event-chain:event-asset"
            ]
        )
    }

    func testTransactionHistoryContext_whenInitializedAndFiltered_thenTracksSourcePagination() {
        let rawContext = [
            "history.page.transfers": "2",
            "history.row.transfers": "40",
            "history.complete.transfers": "false",
            "history.page.rewards": "3",
            "history.row.rewards": "not-a-row",
            "history.complete.rewards": "true",
            "history.page.extrinsics": "5",
            "history.row.extrinsics": "12",
            "history.complete.extrinsics": "false"
        ]

        let context = TransactionHistoryContext(context: rawContext, defaultRow: 25)
        let updatedExtrinsics = context.sourceContext(for: .extrinsics)
            .byReplacingPage(8)
            .byReplacingRow(30)
            .byReplacingCompletion(true)
        let updatedContext = context.byReplacingSource(context: updatedExtrinsics, for: .extrinsics)
        let filteredContext = context.byApplying(filters: [WalletTransactionHistoryFilter(type: .transfer)])
        let emptyFilteredContext = context.byApplying(filters: [])

        XCTAssertEqual(context.transfers.page, 2)
        XCTAssertEqual(context.transfers.row, 40)
        XCTAssertFalse(context.transfers.isComplete)
        XCTAssertEqual(context.rewards.page, 3)
        XCTAssertEqual(context.rewards.row, 25)
        XCTAssertTrue(context.rewards.isComplete)
        XCTAssertEqual(context.extrinsics.page, 5)
        XCTAssertEqual(context.extrinsics.row, 12)
        XCTAssertFalse(context.extrinsics.isComplete)
        XCTAssertFalse(context.isComplete)

        XCTAssertEqual(updatedContext.extrinsics.page, 8)
        XCTAssertEqual(updatedContext.extrinsics.row, 30)
        XCTAssertTrue(updatedContext.extrinsics.isComplete)
        XCTAssertEqual(updatedContext.sourceContext(for: .transfers).page, 2)

        XCTAssertEqual(context.toContext()["history.row.rewards"], "25")
        XCTAssertEqual(context.toContext()["history.complete.transfers"], "false")
        XCTAssertFalse(filteredContext.transfers.isComplete)
        XCTAssertTrue(filteredContext.rewards.isComplete)
        XCTAssertTrue(filteredContext.extrinsics.isComplete)
        XCTAssertTrue(emptyFilteredContext.isComplete)
    }

    func testMapKeyType_whenExtractingKeys_thenUsesExpectedSuffixWindows() {
        let accountId = String(repeating: "a", count: 64)
        let assetId = String(repeating: "b", count: 64)
        let firstAssetId = String(repeating: "c", count: 64)
        let secondAssetId = String(repeating: "d", count: 64)
        let hasher32 = String(repeating: "e", count: 32)
        let hasher16 = String(repeating: "f", count: 16)
        let era = "0000002a"
        let page = "00000003"

        XCTAssertEqual(MapKeyType.u8.bytesCount, 1)
        XCTAssertEqual(MapKeyType.u256.bytesCount, 32)
        XCTAssertEqual(MapKeyType.accountId.bytesCount, 32)
        XCTAssertEqual(MapKeyType.u32.extractKeys(from: "prefix12345678"), "12345678")
        XCTAssertEqual(MapKeyType.accountId.extractKeys(from: "prefix\(accountId)"), accountId)
        XCTAssertEqual(
            MapKeyType.assetIds.extractKeys(from: "prefix\(firstAssetId)\(hasher32)\(secondAssetId)"),
            firstAssetId + secondAssetId
        )
        XCTAssertEqual(
            MapKeyType.accountPoolsKey.extractKeys(from: "prefix\(accountId)\(hasher32)\(assetId)"),
            accountId + assetId
        )
        XCTAssertEqual(
            MapKeyType.poolProvidersKey.extractKeys(from: "prefix\(accountId)\(assetId)"),
            accountId + assetId
        )
        XCTAssertEqual(
            MapKeyType.erasStakersPagedKey.extractKeys(
                from: "prefix\(era)\(hasher16)\(accountId)\(hasher16)\(page)"
            ),
            era + accountId + page
        )
        XCTAssertEqual(
            MapKeyType.erasStakersOverviewKey.extractKeys(from: "prefix\(era)\(hasher16)\(accountId)"),
            era + accountId
        )
    }

    func testDateFormatters_whenLocaleProvided_thenFormatExpectedValues() throws {
        let calendar = Calendar(identifier: .gregorian)
        let date = try XCTUnwrap(
            calendar.date(
                from: DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 0),
                    year: 2024,
                    month: 5,
                    day: 23,
                    hour: 12,
                    minute: 34,
                    second: 56,
                    nanosecond: 789_000_000
                )
            )
        )
        let locale = Locale(identifier: "en_US_POSIX")

        XCTAssertEqual(DateFormatter.iso.string(from: date), "2024-05-23T12:34:56.789Z")
        XCTAssertEqual(DateFormatter.txHistory.value(for: locale).locale, locale)
        XCTAssertFalse(DateFormatter.txDetails.value(for: locale).string(from: date).isEmpty)
        XCTAssertFalse(DateFormatter.shortDate.value(for: locale).string(from: date).isEmpty)
        XCTAssertFalse(DateFormatter.sectionedDate.value(for: locale).string(from: date).isEmpty)
        XCTAssertFalse(DateFormatter.connectionExpiry.value(for: locale).string(from: date).isEmpty)
        XCTAssertEqual(DateFormatter.giantsquidDate.value(for: locale).dateFormat, DateStringFormat.subsquid.rawValue)
        XCTAssertEqual(
            DateFormatter.suibsquidInputDate.value(for: locale).dateFormat,
            DateStringFormat.subsquidInput.rawValue
        )
        XCTAssertEqual(DateFormatter.alchemyDate.value(for: locale).dateFormat, DateStringFormat.alchemy.rawValue)
    }

    func testAsyncSequenceHelpers_whenTransformingValues_thenPreserveOrdering() async throws {
        let values = [1, 2, 3, 4]
        let recorder = AsyncIntRecorder()

        let mapped: [String] = await values.asyncMap { value -> String? in
            value.isMultiple(of: 2) ? nil : "value-\(value)"
        }
        let compactMapped: [Int] = await values.asyncCompactMap { value -> Int? in
            value > 2 ? value * 10 : nil
        }
        let reduced = await values.asyncReduce(0) { partial, value in
            partial + value
        }
        try await values.asyncForEach { value in
            await recorder.append(value)
        }
        let visitedValues = await recorder.snapshot()
        let concurrentlyMapped: [Int] = try await values.concurrentMap { value -> Int? in
            value == 2 ? nil : value * 100
        }

        XCTAssertEqual(mapped, ["value-1", "value-3"])
        XCTAssertEqual(compactMapped, [30, 40])
        XCTAssertEqual(reduced, 10)
        XCTAssertEqual(Set(visitedValues), Set(values))
        XCTAssertEqual(visitedValues.count, values.count)
        XCTAssertEqual(concurrentlyMapped, [100, 300, 400])
    }

    func testHTTPRequestBuilder_whenConfigAndDefaultHeadersProvided_thenBuildsRequest() throws {
        let body = Data([0x01, 0x02, 0x03])
        let builder = HTTPRequestBuilder(
            host: "https://pi.soramitsu.io",
            headerBuilder: TestHTTPHeadersBuilder(headers: [
                "Accept": "application/json",
                "Shared": "default"
            ])
        )
        let config = TestHTTPRequestConfig(
            path: "/graphql",
            httpMethod: HTTPRequestMethod.post.rawValue,
            headers: [
                "Authorization": "Bearer token",
                "Shared": "config"
            ],
            queryParameters: [
                URLQueryItem(name: "network", value: "sora2")
            ],
            bodyData: body
        )

        let request = try builder.buildRequest(with: config)

        XCTAssertEqual(request.url?.absoluteString, "https://pi.soramitsu.io/graphql?network=sora2")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.httpBody, body)
        XCTAssertEqual(request.allHTTPHeaderFields?["Accept"], "application/json")
        XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], "Bearer token")
        XCTAssertEqual(request.allHTTPHeaderFields?["Shared"], "config")
        XCTAssertThrowsError(
            try builder.buildRequest(
                with: TestHTTPRequestConfig(path: "/graphql", throwsOnBody: true)
            )
        ) { error in
            XCTAssertTrue(error is HTTPRequestBuilderError)
        }
    }

    func testSafeDictionary_whenMutated_thenSynchronizesReadsAndCollectionAccess() {
        let dictionary = SafeDictionary(dict: ["one": 1])

        dictionary["two"] = 2
        let firstElement = dictionary[dictionary.startIndex]

        XCTAssertEqual(dictionary["one"], 1)
        XCTAssertEqual(dictionary["two"], 2)
        XCTAssertEqual(Set(dictionary.keys), ["one", "two"])
        XCTAssertEqual(Set(dictionary.values), [1, 2])
        XCTAssertTrue(["one", "two"].contains(firstElement.key))
        XCTAssertTrue([1, 2].contains(firstElement.value))

        dictionary.replace(dict: ["three": 3])
        XCTAssertNil(dictionary["one"])
        XCTAssertEqual(dictionary["three"], 3)

        dictionary.removeValue(forKey: "three")
        XCTAssertNil(dictionary["three"])

        dictionary["four"] = 4
        dictionary.removeAll()
        XCTAssertTrue(dictionary.isEmpty)
    }

    func testPolkaswapJSON_whenEncodingAndDecodingSupportedValues_thenPreservesSingleValuePayloads() throws {
        XCTAssertEqual(try jsonString(from: PolkaswapJSON(UInt32(7))), "7")
        XCTAssertEqual(try jsonString(from: PolkaswapJSON("xor")), "\"xor\"")
        XCTAssertEqual(try jsonString(from: PolkaswapJSON(true)), "true")
        XCTAssertEqual(try jsonString(from: PolkaswapJSON(1.25)), "1.25")
        XCTAssertEqual(
            try XCTUnwrap(jsonFragment(from: PolkaswapJSON(["XYKPool", "Smart"])) as? [String]),
            ["XYKPool", "Smart"]
        )

        XCTAssertEqual(try JSONDecoder().decode(PolkaswapJSON.self, from: data(from: "7")).value() as? UInt32, 7)
        XCTAssertEqual(try JSONDecoder().decode(PolkaswapJSON.self, from: data(from: "\"xor\"")).value() as? String, "xor")
        XCTAssertEqual(try JSONDecoder().decode(PolkaswapJSON.self, from: data(from: "true")).value() as? Bool, true)
        XCTAssertEqual(try JSONDecoder().decode(PolkaswapJSON.self, from: data(from: "1.25")).value() as? Double, 1.25)
        XCTAssertEqual(
            try JSONDecoder().decode(PolkaswapJSON.self, from: data(from: #"["XYKPool","Smart"]"#)).value() as? [String],
            ["XYKPool", "Smart"]
        )
        XCTAssertNil(try JSONDecoder().decode(PolkaswapJSON.self, from: data(from: "null")).value())
    }

    func testAlchemyHistoryRequest_whenEncodingDefaultsAndCustomBlocks_thenBuildsRPCPayload() throws {
        let defaultRequest = AlchemyHistoryRequest(
            fromAddress: "0x0000000000000000000000000000000000000001",
            category: [.erc20, .external]
        )
        let defaultJSON = try jsonObject(from: defaultRequest)

        XCTAssertEqual(defaultJSON["fromBlock"] as? String, "0x0")
        XCTAssertEqual(defaultJSON["toBlock"] as? String, "latest")
        XCTAssertEqual(defaultJSON["category"] as? [String], ["erc20", "external"])
        XCTAssertEqual(defaultJSON["withMetadata"] as? Bool, true)
        XCTAssertEqual(defaultJSON["excludeZeroValue"] as? Bool, true)
        XCTAssertEqual(defaultJSON["fromAddress"] as? String, "0x0000000000000000000000000000000000000001")
        XCTAssertNil(defaultJSON["toAddress"])
        XCTAssertEqual(defaultJSON["order"] as? String, "desc")

        let customRequest = AlchemyHistoryRequest(
            fromBlock: .int(value: 42),
            toBlock: .indexed,
            category: [.internal, .erc721],
            withMetadata: false,
            excludeZeroValue: false,
            maxCount: "0x64",
            fromAddress: nil,
            toAddress: "0x0000000000000000000000000000000000000002",
            order: .asc
        )
        let customJSON = try jsonObject(from: customRequest)

        XCTAssertEqual(customJSON["fromBlock"] as? Int, 42)
        XCTAssertEqual(customJSON["toBlock"] as? String, "indexed")
        XCTAssertEqual(customJSON["category"] as? [String], ["internal", "erc721"])
        XCTAssertEqual(customJSON["withMetadata"] as? Bool, false)
        XCTAssertEqual(customJSON["excludeZeroValue"] as? Bool, false)
        XCTAssertEqual(customJSON["maxCount"] as? String, "0x64")
        XCTAssertNil(customJSON["fromAddress"])
        XCTAssertEqual(customJSON["toAddress"] as? String, "0x0000000000000000000000000000000000000002")
        XCTAssertEqual(customJSON["order"] as? String, "asc")
    }

    func testExistentialDepositCurrencyId_whenInitializedAndEncoded_thenMatchesRPCParameterShape() throws {
        let orml = try XCTUnwrap(
            ExistentialDepositCurrencyId(from: CurrencyId.ormlAsset(symbol: TokenSymbol(symbol: "dot")))
        )
        let foreignAsset = try XCTUnwrap(
            ExistentialDepositCurrencyId(from: CurrencyId.foreignAsset(foreignAsset: "42"))
        )
        let liquidCrowdloan = try XCTUnwrap(
            ExistentialDepositCurrencyId(from: CurrencyId.liquidCrowdloan(liquidCrowdloan: "lcdot"))
        )
        let stableAsset = try XCTUnwrap(
            ExistentialDepositCurrencyId(from: CurrencyId.stableAssetPoolToken(stableAssetPoolToken: "ksm"))
        )
        let vToken = try XCTUnwrap(
            ExistentialDepositCurrencyId(from: CurrencyId.vToken(symbol: TokenSymbol(symbol: "bnc")))
        )
        let vsToken = try XCTUnwrap(
            ExistentialDepositCurrencyId(from: CurrencyId.vsToken(symbol: TokenSymbol(symbol: "ksm")))
        )
        let stable = try XCTUnwrap(
            ExistentialDepositCurrencyId(from: CurrencyId.stable(symbol: TokenSymbol(symbol: "usd")))
        )

        XCTAssertEqual(try jsonObject(from: orml)["token"] as? String, "DOT")
        XCTAssertEqual(try jsonObject(from: foreignAsset)["foreignAsset"] as? Int, 42)
        XCTAssertEqual(try jsonObject(from: liquidCrowdloan)["liquidCrowdloan"] as? String, "lcdot")
        XCTAssertEqual(try jsonObject(from: stableAsset)["stableAssetPoolToken"] as? String, "ksm")
        XCTAssertEqual(try jsonObject(from: vToken)["vToken"] as? String, "BNC")
        XCTAssertEqual(try jsonObject(from: vsToken)["vsToken"] as? String, "KSM")
        XCTAssertEqual(try jsonObject(from: stable)["stable"] as? String, "USD")
        XCTAssertEqual(
            try jsonObject(from: ExistentialDepositCurrencyId.token2(tokenSymbol: "KAR"))["token2"] as? String,
            "KAR"
        )

        XCTAssertNil(ExistentialDepositCurrencyId(from: nil))
        XCTAssertNil(ExistentialDepositCurrencyId(from: CurrencyId.ormlAsset(symbol: nil)))
        XCTAssertNil(ExistentialDepositCurrencyId(from: CurrencyId.foreignAsset(foreignAsset: "not-a-number")))
        XCTAssertNil(ExistentialDepositCurrencyId(from: CurrencyId.equilibrium(id: "eq")))
        XCTAssertNil(ExistentialDepositCurrencyId(from: CurrencyId.soraAsset(id: "sora")))
        XCTAssertNil(ExistentialDepositCurrencyId(from: CurrencyId.assets(id: "assets")))
        XCTAssertNil(ExistentialDepositCurrencyId(from: CurrencyId.xcm(id: "xcm")))
    }

    func testSwapMarketSource_whenLoaded_thenAddsSmartLocallyAndFiltersRemoteSources() throws {
        let settings = PolkaswapRemoteSettings(
            version: "1",
            availableDexIds: [],
            availableSources: [.xyk, .tbc],
            forceSmartIds: ["xor"],
            xstusdId: "xstusd"
        )

        XCTAssertNil(SwapMarketSource(fromAssetId: nil, toAssetId: "xor", remoteSettings: settings))
        XCTAssertNil(SwapMarketSource(fromAssetId: "xor", toAssetId: nil, remoteSettings: settings))

        let source = try XCTUnwrap(SwapMarketSource(fromAssetId: "xor", toAssetId: "val", remoteSettings: settings))

        XCTAssertFalse(source.isLoaded())
        XCTAssertTrue(source.isEmpty())
        XCTAssertEqual(source.getMarketSources(), [.smart])
        XCTAssertNil(source.getMarketSource(at: 0))
        XCTAssertEqual(source.getRemoteMarketSources(), [])

        source.didLoad([.xyk, .tbc])

        XCTAssertTrue(source.isLoaded())
        XCTAssertFalse(source.isEmpty())
        XCTAssertEqual(source.getMarketSources(), [.xyk, .tbc, .smart])
        XCTAssertEqual(source.getMarketSource(at: 1), .tbc)
        XCTAssertEqual(source.index(of: .smart), 2)
        XCTAssertTrue(source.contains(.xyk))
        XCTAssertEqual(source.getRemoteMarketSources(), ["XYKPool", "MulticollateralBondingCurvePool"])

        let smartOnlySource = try XCTUnwrap(
            SwapMarketSource(fromAssetId: "xstusd", toAssetId: "xor", remoteSettings: settings)
        )
        smartOnlySource.didLoad([])

        XCTAssertEqual(smartOnlySource.getMarketSources(), [.smart])
        XCTAssertEqual(smartOnlySource.getRemoteMarketSources(), [])
    }

    func testKmmCallCodingPath_whenStaticPathsQueried_thenClassifiesKnownSoraCalls() throws {
        XCTAssertEqual(KmmCallCodingPath.transfer.moduleName, "assets")
        XCTAssertEqual(KmmCallCodingPath.transfer.callName, "transfer")
        XCTAssertEqual(KmmCallCodingPath.transferKeepAlive.callName, "transferKeepAlive")
        XCTAssertEqual(KmmCallCodingPath.swap.moduleName, "liquidityProxy")
        XCTAssertEqual(KmmCallCodingPath.swap.callName, "swap")
        XCTAssertEqual(KmmCallCodingPath.migration.moduleName, "irohaMigration")
        XCTAssertEqual(KmmCallCodingPath.depositLiquidity.moduleName, "poolXYK")
        XCTAssertEqual(KmmCallCodingPath.depositLiquidity.callName, "depositLiquidity")
        XCTAssertEqual(KmmCallCodingPath.withdrawLiquidity.callName, "withdrawLiquidity")
        XCTAssertEqual(KmmCallCodingPath.setReferral.callName, "setReferrer")
        XCTAssertEqual(KmmCallCodingPath.bondReferralBalance.callName, "reserve")
        XCTAssertEqual(KmmCallCodingPath.unbondReferralBalance.callName, "unreserve")
        XCTAssertEqual(KmmCallCodingPath.batchUtility.callName, "batch")
        XCTAssertEqual(KmmCallCodingPath.batchAllUtility.callName, "batchAll")

        XCTAssertTrue(KmmCallCodingPath.transfer.isTransfer)
        XCTAssertTrue(KmmCallCodingPath.transferKeepAlive.isTransfer)
        XCTAssertFalse(KmmCallCodingPath.swap.isTransfer)
        XCTAssertTrue(KmmCallCodingPath.swap.isSwap)
        XCTAssertTrue(KmmCallCodingPath.migration.isMigration)
        XCTAssertTrue(KmmCallCodingPath.depositLiquidity.isDepositLiquidity)
        XCTAssertTrue(KmmCallCodingPath.withdrawLiquidity.isWithdrawLiquidity)
        XCTAssertTrue(KmmCallCodingPath.setReferral.isReferral)
        XCTAssertTrue(KmmCallCodingPath.bondReferralBalance.isReferral)
        XCTAssertTrue(KmmCallCodingPath.unbondReferralBalance.isReferral)
        XCTAssertFalse(KmmCallCodingPath.batchUtility.isReferral)

        let encoded = try JSONEncoder().encode(KmmCallCodingPath.swap)
        let decoded = try JSONDecoder().decode(KmmCallCodingPath.self, from: encoded)

        XCTAssertEqual(decoded, .swap)
    }

    func testStorageUpdateData_whenDecoded_thenNormalizesHexChangesAndDropsInvalidRows() throws {
        let update = try JSONDecoder().decode(
            StorageUpdate.self,
            from: data(
                from: """
                {
                    "block": "0x0102",
                    "changes": [
                        ["0x0a", "0x0b0c"],
                        ["0x0d", null],
                        ["bad", "0x01"],
                        ["0x01"],
                        [null, "0x02"],
                        ["0x0e", "not-hex"]
                    ]
                }
                """
            )
        )
        let updateData = StorageUpdateData(update: update)

        XCTAssertEqual(updateData.blockHash, Data([0x01, 0x02]))
        XCTAssertEqual(updateData.changes.count, 3)
        XCTAssertEqual(updateData.changes[0].key, Data([0x0A]))
        XCTAssertEqual(updateData.changes[0].value, Data([0x0B, 0x0C]))
        XCTAssertEqual(updateData.changes[1].key, Data([0x0D]))
        XCTAssertNil(updateData.changes[1].value)
        XCTAssertEqual(updateData.changes[2].key, Data([0x0E]))
        XCTAssertNil(updateData.changes[2].value)

        let invalidBlockUpdate = try JSONDecoder().decode(
            StorageUpdate.self,
            from: data(from: #"{"block":"not-hex","changes":null}"#)
        )
        let invalidBlockUpdateData = StorageUpdateData(update: invalidBlockUpdate)

        XCTAssertNil(invalidBlockUpdateData.blockHash)
        XCTAssertTrue(invalidBlockUpdateData.changes.isEmpty)
    }

    func testOperationCombiningService_whenStarted_thenTracksStateRejectsRestartsAndCancelsWrappers() {
        let manager = CapturingOperationManager()
        let firstOperation = ClosureOperation<Int> { 1 }
        let secondOperation = ClosureOperation<Int> { 2 }
        let firstWrapper = CompoundOperationWrapper(targetOperation: firstOperation)
        let secondWrapper = CompoundOperationWrapper(targetOperation: secondOperation)
        let service = OperationCombiningService<Int>(
            operationManager: manager,
            operationsPerBatch: 1
        ) {
            [firstWrapper, secondWrapper]
        }
        var firstCompletionCalled = false

        service.start { _ in
            firstCompletionCalled = true
        }

        XCTAssertEqual(service.state, .running)
        XCTAssertFalse(firstCompletionCalled)
        XCTAssertEqual(manager.enqueuedOperations.count, 3)
        XCTAssertEqual(manager.modes.count, 1)
        XCTAssertTrue(manager.modes.allSatisfy(\.isTransient))
        XCTAssertTrue(secondOperation.dependencies.contains(firstOperation))

        var secondStartError: Error?

        service.start { result in
            if case let .failure(error) = result {
                secondStartError = error
            } else {
                XCTFail("Expected restart to fail")
            }
        }

        if case OperationCombiningServiceError.alreadyRunningOrFinished? = secondStartError {
            XCTAssertTrue(true)
        } else {
            XCTFail("Unexpected restart error: \(String(describing: secondStartError))")
        }

        service.cancel()

        XCTAssertEqual(service.state, .finished)
        XCTAssertTrue(firstOperation.isCancelled)
        XCTAssertTrue(secondOperation.isCancelled)
    }

    func testOperationCombiningService_whenOperationsComplete_thenCombinesResultsInOrder() throws {
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1
        let manager = OperationManager(operationQueue: operationQueue)
        let service = OperationCombiningService<Int>(operationManager: manager) {
            [
                CompoundOperationWrapper(targetOperation: ClosureOperation { 1 }),
                CompoundOperationWrapper(targetOperation: ClosureOperation { 2 })
            ]
        }
        let expectation = XCTestExpectation()
        var completionResult: Result<[Int], Error>?

        service.start { result in
            completionResult = result
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)

        XCTAssertEqual(service.state, .finished)
        let values = try completionResult?.get()
        XCTAssertEqual(values, [1, 2])
    }

    func testOperationCombiningService_whenOperationsClosureThrows_thenFinishesWithError() {
        let service = OperationCombiningService<Int>(
            operationManager: CapturingOperationManager()
        ) {
            throw TestEventError.sample
        }
        var completionError: Error?

        service.start { result in
            if case let .failure(error) = result {
                completionError = error
            } else {
                XCTFail("Expected operation closure failure")
            }
        }

        XCTAssertEqual(service.state, .finished)
        if case TestEventError.sample? = completionError {
            XCTAssertTrue(true)
        } else {
            XCTFail("Unexpected completion error: \(String(describing: completionError))")
        }
    }

    func testManualOperation_whenStartedWithoutResult_thenRunsUntilFinishedManually() {
        let operation = ManualOperation<Int>()

        operation.start()

        XCTAssertTrue(operation.isAsynchronous)
        XCTAssertTrue(operation.isExecuting)
        XCTAssertFalse(operation.isFinished)
        XCTAssertNil(operation.result)

        operation.finish()

        XCTAssertFalse(operation.isExecuting)
        XCTAssertTrue(operation.isFinished)
    }

    func testManualOperation_whenResultOrCancellationExists_thenFinishesOnStart() throws {
        let successfulOperation = ManualOperation<Int>()
        successfulOperation.result = .success(42)

        successfulOperation.start()

        XCTAssertFalse(successfulOperation.isExecuting)
        XCTAssertTrue(successfulOperation.isFinished)
        XCTAssertEqual(try successfulOperation.result?.get(), 42)

        let cancelledOperation = ManualOperation<Int>()
        cancelledOperation.cancel()

        cancelledOperation.start()

        XCTAssertFalse(cancelledOperation.isExecuting)
        XCTAssertTrue(cancelledOperation.isFinished)
        XCTAssertNil(cancelledOperation.result)
    }

    func testLongrunOperation_whenLongrunCompletes_thenStoresResultAndFinishes() throws {
        let startedExpectation = expectation(description: "longrun started")
        let longrun = RecordingLongrun<Int> {
            startedExpectation.fulfill()
        }
        let operation = LongrunOperation(longrun: AnyLongrun(longrun: longrun))

        operation.start()

        wait(for: [startedExpectation], timeout: 2)
        XCTAssertTrue(operation.isAsynchronous)
        XCTAssertTrue(operation.isExecuting)
        XCTAssertFalse(operation.isFinished)

        longrun.complete(.success(7))

        XCTAssertFalse(operation.isExecuting)
        XCTAssertTrue(operation.isFinished)
        XCTAssertEqual(try operation.result?.get(), 7)
    }

    func testLongrunOperation_whenCancelled_thenCancelsWrappedLongrunAndFinishes() {
        let startedExpectation = expectation(description: "longrun started")
        let longrun = RecordingLongrun<Int> {
            startedExpectation.fulfill()
        }
        let operation = LongrunOperation(longrun: AnyLongrun(longrun: longrun))

        operation.start()

        wait(for: [startedExpectation], timeout: 2)
        operation.cancel()

        XCTAssertEqual(longrun.cancelCallCount, 1)
        XCTAssertFalse(operation.isExecuting)
        XCTAssertTrue(operation.isFinished)
    }

    private enum ExpectedSignatureKind {
        case sr25519
        case ed25519
        case ecdsa
    }

    private func assertSignature(
        _ signature: MultiSignature,
        matches expectedKind: ExpectedSignatureKind,
        data expectedData: Data,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch (signature, expectedKind) {
        case let (.sr25519(data), .sr25519),
             let (.ed25519(data), .ed25519),
             let (.ecdsa(data), .ecdsa):
            XCTAssertEqual(data, expectedData, file: file, line: line)
        default:
            XCTFail("Unexpected signature kind", file: file, line: line)
        }
    }

    private func makeChain(
        chainId: ChainModel.Id,
        name: String = "Test",
        addressPrefix: UInt16 = 0,
        assets: Set<AssetModel> = [],
        options: [ChainOptions]? = nil,
        icon: URL = URL(string: "https://example.com/icon.svg")!
    ) -> ChainModel {
        let node = ChainNodeModel(
            url: URL(string: "wss://node.example")!,
            name: "node",
            apikey: nil
        )

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            paraId: nil,
            name: name,
            assets: assets,
            xcm: nil,
            nodes: Set([node]),
            addressPrefix: addressPrefix,
            icon: icon,
            options: options,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func makeMetaAccount(
        metaId: String = "meta-id",
        ethereumPublicKey: Data? = Data(repeating: 0x04, count: 33),
        chainAccounts: Set<ChainAccountModel> = [],
        assetsVisibility: [AssetVisibility] = []
    ) -> MetaAccountModel {
        MetaAccountModel(
            metaId: metaId,
            name: "Fearless",
            substrateAccountId: Data(repeating: 0x01, count: 32),
            substrateCryptoType: CryptoType.sr25519.rawValue,
            substratePublicKey: Data(repeating: 0x02, count: 32),
            ethereumAddress: Data(repeating: 0x03, count: 20),
            ethereumPublicKey: ethereumPublicKey,
            chainAccounts: chainAccounts,
            assetKeysOrder: nil,
            canExportEthereumMnemonic: true,
            unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(),
            networkManagmentFilter: nil,
            assetsVisibility: assetsVisibility,
            hasBackup: true,
            favouriteChainIds: []
        )
    }

    private func makeHistoryAsset(
        id: String = "asset",
        precision: UInt16 = 2,
        staking: RawStakingType? = nil
    ) -> AssetModel {
        AssetModel(
            id: id,
            name: "History Asset",
            symbol: "HST",
            precision: precision,
            icon: nil,
            isUtility: true,
            isNative: true,
            staking: staking,
            type: .normal
        )
    }

    private func pricedAsset(
        id: String,
        price: String,
        fiatDayChange: String?,
        priceProvider: PriceProvider?,
        coingeckoPriceId: String?
    ) -> AssetModel {
        AssetModel(
            id: id,
            name: id.uppercased(),
            symbol: id.uppercased(),
            precision: 18,
            price: decimal(price),
            fiatDayChange: fiatDayChange.map(decimal),
            isUtility: false,
            isNative: false,
            type: .normal,
            priceProvider: priceProvider,
            coingeckoPriceId: coingeckoPriceId
        )
    }

    private func decimal(_ value: String) -> Decimal {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))!
    }

    private func balanceLockPayload(displayId: String, amount: UInt64) -> String {
        let idBytes = displayId.utf8.map { "\"\($0)\"" }.joined(separator: ",")

        return """
        {"id":[\(idBytes)],"amount":"\(amount)","reasons":["All"]}
        """
    }

    private func data(from json: String) throws -> Data {
        try XCTUnwrap(json.data(using: .utf8))
    }

    private func jsonString<T: Encodable>(from value: T) throws -> String {
        let encoded = try JSONEncoder().encode(value)
        return try XCTUnwrap(String(data: encoded, encoding: .utf8))
    }

    private func jsonObject<T: Encodable>(from value: T) throws -> [String: Any] {
        try XCTUnwrap(jsonFragment(from: value) as? [String: Any])
    }

    private func jsonFragment<T: Encodable>(from value: T) throws -> Any {
        let encoded = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: encoded, options: [.fragmentsAllowed])
    }

    private func assertMediaType(
        _ expected: MediaType,
        for url: URL,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let mediaType = await MediaType.mediaType(from: url)

        try assertMediaType(mediaType, equals: expected, file: file, line: line)
    }

    private func assertCachedMediaType(
        _ expected: MediaType,
        for url: URL,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try assertMediaType(MediaTypeCache.shared.cache[url], equals: expected, file: file, line: line)
    }

    private func assertMediaType(
        _ actual: MediaType?,
        equals expected: MediaType,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        switch (actual, expected) {
        case (.image?, .image),
             (.video?, .video),
             (.gif?, .gif):
            break
        default:
            XCTFail("Unexpected media type", file: file, line: line)
        }
    }

    private func makeAmountInputFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSize = 3
        formatter.secondaryGroupingSize = 3
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }
}

private final class SelectionObserver: SelectionListViewModelObserver {
    private(set) var changeCount = 0

    func didChangeSelection() {
        changeCount += 1
    }
}

private struct SumReducer: ListReducing {
    func reduce(list: [Int], initialValue: Int) -> Int {
        list.reduce(initialValue, +)
    }
}

private struct TestRemoteImageFactory: RemoteImageViewModelFactoryProtocol {}

private struct GraphQLFixture: Decodable, Equatable {
    let value: Int
}

private struct NomisDateFixture: Decodable {
    let date: Date
}

private struct TestDeactivatableView: DeactivatableView {
    let deactivatableViews: [UIView]
}

private struct TestErrorContentConvertible: Error, ErrorContentConvertible {
    let content: ErrorContent

    func toErrorContent(for _: Locale?) -> ErrorContent {
        content
    }
}

private final class SheetAlertPresentableSpy: SheetAlertPresentable {
    private(set) var presentedMessages: [PresentedMessage] = []
    private(set) var presentedViewModels: [SheetAlertPresentableViewModel] = []
    private(set) var presentedInfoMessages: [PresentedMessage] = []

    func present(
        viewModel: SheetAlertPresentableViewModel,
        from _: ControllerBackedProtocol?
    ) {
        presentedViewModels.append(viewModel)
    }

    func present(
        message: String?,
        title: String,
        closeAction: String?,
        from _: ControllerBackedProtocol?
    ) {
        presentedMessages.append(PresentedMessage(
            message: message,
            title: title,
            closeAction: closeAction,
            actions: []
        ))
    }

    func present(
        message: String?,
        title: String,
        closeAction: String?,
        from _: ControllerBackedProtocol?,
        actions: [SheetAlertPresentableAction]
    ) {
        presentedMessages.append(PresentedMessage(
            message: message,
            title: title,
            closeAction: closeAction,
            actions: actions
        ))
    }

    func presentInfo(
        message: String?,
        title: String,
        from _: ControllerBackedProtocol?
    ) {
        presentedInfoMessages.append(PresentedMessage(
            message: message,
            title: title,
            closeAction: nil,
            actions: []
        ))
    }
}

private struct PresentedMessage {
    let message: String?
    let title: String
    let closeAction: String?
    let actions: [SheetAlertPresentableAction]
}

private actor AsyncIntRecorder {
    private var values: [Int] = []

    func append(_ value: Int) {
        values.append(value)
    }

    func snapshot() -> [Int] {
        values
    }
}

private struct TestHTTPHeadersBuilder: HTTPHeadersBuilderProtocol {
    let headers: [String: String]?

    func buildHeaders() -> [String: String]? {
        headers
    }
}

private struct TestHTTPRequestConfig: HTTPRequestConfig {
    let path: String
    let httpMethod: String
    let headers: [String: String]?
    let queryParameters: [URLQueryItem]?
    let bodyData: Data?
    let throwsOnBody: Bool

    init(
        path: String,
        httpMethod: String = HTTPRequestMethod.get.rawValue,
        headers: [String: String]? = nil,
        queryParameters: [URLQueryItem]? = nil,
        bodyData: Data? = nil,
        throwsOnBody: Bool = false
    ) {
        self.path = path
        self.httpMethod = httpMethod
        self.headers = headers
        self.queryParameters = queryParameters
        self.bodyData = bodyData
        self.throwsOnBody = throwsOnBody
    }

    func body() throws -> Data? {
        if throwsOnBody {
            throw TestEventError.sample
        }

        return bodyData
    }
}

private final class CapturingOperationManager: OperationManagerProtocol {
    private(set) var enqueuedOperations: [Operation] = []
    private(set) var modes: [OperationMode] = []

    func enqueue(operations: [Operation], in mode: OperationMode) {
        enqueuedOperations.append(contentsOf: operations)
        modes.append(mode)
    }
}

private extension OperationMode {
    var isTransient: Bool {
        if case .transient = self {
            return true
        }

        return false
    }
}

private final class RecordingLongrun<T>: Longrunable {
    typealias ResultType = T

    private let lock = NSLock()
    private let onStart: () -> Void
    private var completionClosure: ((Result<T, Error>) -> Void)?
    private var _cancelCallCount = 0

    var cancelCallCount: Int {
        lock.lock()
        defer {
            lock.unlock()
        }

        return _cancelCallCount
    }

    init(onStart: @escaping () -> Void = {}) {
        self.onStart = onStart
    }

    func start(with completionClosure: @escaping (Result<T, Error>) -> Void) {
        lock.lock()
        self.completionClosure = completionClosure
        lock.unlock()

        onStart()
    }

    func cancel() {
        lock.lock()
        _cancelCallCount += 1
        lock.unlock()
    }

    func complete(_ result: Result<T, Error>) {
        lock.lock()
        let completionClosure = completionClosure
        lock.unlock()

        completionClosure?(result)
    }
}

private final class AmountInputObserver: NSObject, AmountInputViewModelObserver {
    private(set) var changeCount = 0

    func amountInputDidChange() {
        changeCount += 1
    }
}

private final class AmountInputAccessoryDelegateRecorder: AmountInputAccessoryViewDelegate {
    private(set) var percentages: [Float] = []
    private(set) var selectedViews: [AmountInputAccessoryView] = []
    private(set) var doneViews: [AmountInputAccessoryView] = []

    var doneCallCount: Int {
        doneViews.count
    }

    func didSelect(on view: AmountInputAccessoryView, percentage: Float) {
        selectedViews.append(view)
        percentages.append(percentage)
    }

    func didSelectDone(on view: AmountInputAccessoryView) {
        doneViews.append(view)
    }
}

private final class TestPresentingViewController: UIViewController {
    private let overridePresentedViewController: UIViewController?

    override var presentedViewController: UIViewController? {
        overridePresentedViewController
    }

    init(presentedViewController: UIViewController?) {
        overridePresentedViewController = presentedViewController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class TestLocalizationManager: LocalizationManagerProtocol {
    var selectedLocalization: String
    let availableLocalizations: [String]

    init(selectedLocalization: String, availableLocalizations: [String]) {
        self.selectedLocalization = selectedLocalization
        self.availableLocalizations = availableLocalizations
    }

    func addObserver(
        with _: AnyObject,
        queue _: DispatchQueue?,
        closure _: @escaping LocalizationChangeClosure
    ) {}

    func removeObserver(by _: AnyObject) {}
}

private final class LanguageSelectionPresenterRecorder: LanguageSelectionInteractorOutputProtocol {
    private(set) var loadedLanguages: [[Language]] = []
    private(set) var selectedLanguages: [Language] = []

    var selectedLanguageCodes: [String] {
        selectedLanguages.map(\.code)
    }

    func didLoad(selectedLanguage: Language) {
        selectedLanguages.append(selectedLanguage)
    }

    func didLoad(languages: [Language]) {
        loadedLanguages.append(languages)
    }
}

private enum TestCodingKey: String, CodingKey {
    case value
}

private struct StringLengthMapper: Mapping {
    func map(input: String) -> Int {
        input.count
    }
}

private enum TestEventError: Error {
    case sample
}

private final class EventVisitorRecorder: EventVisitorProtocol {
    private(set) var calls: [String] = []

    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        calls.append("selectedAccount:\(event.account.metaId)")
    }

    func processPricesUpdated() {
        calls.append("prices")
    }

    func processNewTransaction(event _: WalletNewTransactionInserted) {
        calls.append("newTransaction")
    }

    func processAccountScoreSettingsChanged() {
        calls.append("accountScoreSettings")
    }

    func processBalanceChanged(event _: WalletBalanceChanged) {
        calls.append("balance")
    }

    func processSelectedUsernameChanged(event _: SelectedUsernameChanged) {
        calls.append("selectedUsername")
    }

    func processPurchaseCompletion(event _: PurchaseCompleted) {
        calls.append("purchase")
    }

    func processStakingChanged(event _: WalletStakingInfoChanged) {
        calls.append("staking")
    }

    func processSelectedConnectionChanged(event _: SelectedConnectionChanged) {
        calls.append("selectedConnection")
    }

    func processEraStakersInfoChanged(event _: EraStakersInfoChanged) {
        calls.append("eraStakers")
    }

    func processWalletNameChanged(event: WalletNameChanged) {
        calls.append("walletName:\(event.wallet.metaId)")
    }

    func processStakingUpdatedEvent() {
        calls.append("stakingUpdated")
    }

    func processChainsSetupCompleted() {
        calls.append("chainsSetup")
    }

    func processLogout() {
        calls.append("logout")
    }

    func processChainSyncDidStart(event _: ChainSyncDidStart) {
        calls.append("chainSyncStart")
    }

    func processChainSyncDidComplete(event: ChainSyncDidComplete) {
        calls.append("chainSyncComplete:\(event.newOrUpdatedChains.count):\(event.removedChains.count)")
    }

    func processChainSyncDidFail(event _: ChainSyncDidFail) {
        calls.append("chainSyncFail")
    }

    func processChainsUpdated(event: ChainsUpdatedEvent) {
        let chainIds = event.updatedChains.map { $0.chainId }.joined(separator: ",")
        calls.append("chainsUpdated:\(chainIds)")
    }

    func processRuntimeChainsTypesSyncCompleted(event: RuntimeChainsTypesSyncCompleted) {
        let keys = event.versioningMap.keys.sorted().joined(separator: ",")
        calls.append("runtimeChainsTypes:\(keys)")
    }

    func processRuntimeSnapshorReady(event: RuntimeSnapshotReady) {
        calls.append("runtimeSnapshot:\(event.chainModel.chainId)")
    }

    func processTypeRegistryPrepared(event: TypeRegistryPrepared) {
        calls.append("typeRegistry:\(event.version)")
    }

    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        calls.append("metaAccount:\(event.account.metaId)")
    }

    func processRemoteSubscriptionWasUpdated(event: WalletRemoteSubscriptionWasUpdatedEvent) {
        calls.append("remoteSubscription:\(event.chainAsset.chain.chainId):\(event.chainAsset.asset.id)")
    }
}

final class ABIParsingTests: XCTestCase {
    func testRecordParse_whenFunctionHasTupleInputAndTupleArrayOutput_thenBuildsFunctionElement() throws {
        let record = ABI.Record(
            name: "quote",
            type: "function",
            payable: false,
            constant: nil,
            stateMutability: "view",
            inputs: [
                ABI.Input(
                    name: "route",
                    type: "tuple",
                    indexed: nil,
                    components: [
                        ABI.Input(name: "dexId", type: "uint32", indexed: nil, components: nil),
                        ABI.Input(name: "assetId", type: "bytes32", indexed: nil, components: nil)
                    ]
                ),
                ABI.Input(name: "amounts", type: "uint256[]", indexed: nil, components: nil)
            ],
            outputs: [
                ABI.Output(
                    name: "routes",
                    type: "tuple[]",
                    components: [
                        ABI.Output(name: "source", type: "string", components: nil),
                        ABI.Output(name: "weight", type: "uint64", components: nil)
                    ]
                )
            ],
            anonymous: nil
        )

        let element = try record.parse()

        guard case let .function(function) = element else {
            return XCTFail("Function element expected")
        }
        XCTAssertEqual(function.name, "quote")
        XCTAssertTrue(function.constant)
        XCTAssertFalse(function.payable)
        XCTAssertEqual(function.inputs.count, 2)
        XCTAssertEqual(function.outputs.count, 1)

        guard case let .tuple(inputTypes) = function.inputs[0].type else {
            return XCTFail("Tuple input expected")
        }
        XCTAssertEqual(inputTypes, [.uint(bits: 32), .bytes(length: 32)])

        guard case let .array(outputSubtype, outputLength) = function.outputs[0].type else {
            return XCTFail("Tuple array output expected")
        }
        XCTAssertEqual(outputLength, 0)
        guard case let .tuple(outputTypes) = outputSubtype else {
            return XCTFail("Tuple array subtype expected")
        }
        XCTAssertEqual(outputTypes, [.string, .uint(bits: 64)])
    }

    func testRecordParse_whenParsingConstructorFallbackAndEvent_thenMapsElementFlagsAndInputs() throws {
        let constructorElement = try ABI.Record(
            name: nil,
            type: "constructor",
            payable: false,
            constant: nil,
            stateMutability: "payable",
            inputs: [ABI.Input(name: "owner", type: "address", indexed: nil, components: nil)],
            outputs: nil,
            anonymous: nil
        ).parse()

        guard case let .constructor(constructor) = constructorElement else {
            return XCTFail("Constructor element expected")
        }
        XCTAssertEqual(constructor.inputs.map(\.type), [.address])
        XCTAssertFalse(constructor.constant)
        XCTAssertTrue(constructor.payable)

        let fallbackElement = try ABI.Record(
            name: nil,
            type: "fallback",
            payable: false,
            constant: false,
            stateMutability: "pure",
            inputs: nil,
            outputs: nil,
            anonymous: nil
        ).parse()

        guard case let .fallback(fallback) = fallbackElement else {
            return XCTFail("Fallback element expected")
        }
        XCTAssertTrue(fallback.constant)
        XCTAssertFalse(fallback.payable)

        let eventElement = try ABI.Record(
            name: "Transfer",
            type: "event",
            payable: nil,
            constant: nil,
            stateMutability: nil,
            inputs: [
                ABI.Input(name: "from", type: "address", indexed: true, components: nil),
                ABI.Input(name: "value", type: "uint", indexed: nil, components: nil)
            ],
            outputs: nil,
            anonymous: true
        ).parse()

        guard case let .event(event) = eventElement else {
            return XCTFail("Event element expected")
        }
        XCTAssertEqual(event.name, "Transfer")
        XCTAssertTrue(event.anonymous)
        XCTAssertEqual(event.inputs.count, 2)
        XCTAssertEqual(event.inputs[0].type, .address)
        XCTAssertTrue(event.inputs[0].indexed)
        XCTAssertEqual(event.inputs[1].type, .uint(bits: 256))
        XCTAssertFalse(event.inputs[1].indexed)
    }

    func testRecordParse_whenRecordTypeOrParameterTypeIsInvalid_thenThrowsParsingError() {
        XCTAssertThrowsError(
            try ABI.Record(
                name: nil,
                type: "receive",
                payable: nil,
                constant: nil,
                stateMutability: nil,
                inputs: nil,
                outputs: nil,
                anonymous: nil
            ).parse()
        ) { error in
            guard case ABI.ParsingError.elementTypeInvalid = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertThrowsError(
            try ABI.Record(
                name: "broken",
                type: "function",
                payable: false,
                constant: nil,
                stateMutability: nil,
                inputs: [ABI.Input(name: "value", type: "map", indexed: nil, components: nil)],
                outputs: nil,
                anonymous: nil
            ).parse()
        ) { error in
            guard case ABI.ParsingError.elementTypeInvalid = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }
}

final class ABIParameterTypeTests: XCTestCase {
    typealias ParameterType = ABI.Element.ParameterType

    func testParameterTypeProperties_whenStaticAndDynamicTypes_thenReportExpectedMemoryAndKinds() {
        let staticArray = ParameterType.array(type: .uint(bits: 256), length: 3)
        let dynamicArray = ParameterType.array(type: .string, length: 2)
        let unboundedArray = ParameterType.array(type: .bool, length: 0)
        let staticTuple = ParameterType.tuple(types: [.address, .bytes(length: 8), staticArray])
        let dynamicTuple = ParameterType.tuple(types: [.address, .dynamicBytes])

        XCTAssertTrue(ParameterType.uint(bits: 256).isNumber)
        XCTAssertTrue(ParameterType.int(bits: 128).isNumber)
        XCTAssertFalse(ParameterType.bool.isNumber)

        XCTAssertTrue(staticArray.isArray)
        XCTAssertFalse(ParameterType.address.isArray)
        XCTAssertTrue(staticTuple.isTuple)
        XCTAssertFalse(ParameterType.address.isTuple)
        XCTAssertEqual(staticArray.subtype, .uint(bits: 256))
        XCTAssertNil(ParameterType.address.subtype)

        XCTAssertTrue(staticArray.isStatic)
        XCTAssertFalse(dynamicArray.isStatic)
        XCTAssertFalse(unboundedArray.isStatic)
        XCTAssertTrue(staticTuple.isStatic)
        XCTAssertFalse(dynamicTuple.isStatic)

        XCTAssertEqual(staticArray.memoryUsage, 96)
        XCTAssertEqual(dynamicArray.memoryUsage, 32)
        XCTAssertEqual(unboundedArray.memoryUsage, 32)
        XCTAssertEqual(staticTuple.memoryUsage, 160)
        XCTAssertEqual(dynamicTuple.memoryUsage, 32)

        guard case let .staticSize(staticArraySize) = staticArray.arraySize else {
            return XCTFail("Static array size expected")
        }
        XCTAssertEqual(staticArraySize, 3)

        guard case .dynamicSize = unboundedArray.arraySize else {
            return XCTFail("Dynamic array size expected")
        }

        guard case .notArray = ParameterType.address.arraySize else {
            return XCTFail("Non-array marker expected")
        }
    }

    func testParameterTypeEmptyValue_whenTypeVaries_thenReturnsABICompatibleZeroValues() throws {
        XCTAssertEqual(ParameterType.uint(bits: 256).emptyValue as? BigUInt, BigUInt(0))
        XCTAssertEqual(ParameterType.int(bits: 128).emptyValue as? BigUInt, BigUInt(0))
        XCTAssertEqual(ParameterType.bool.emptyValue as? Bool, false)
        XCTAssertEqual(ParameterType.string.emptyValue as? String, "")
        XCTAssertEqual(ParameterType.dynamicBytes.emptyValue as? Data, Data())
        XCTAssertEqual(ParameterType.function.emptyValue as? Data, Data(repeating: 0, count: 24))
        XCTAssertEqual(ParameterType.bytes(length: 3).emptyValue as? Data, Data(repeating: 0, count: 3))

        let zeroAddress = try XCTUnwrap(ParameterType.address.emptyValue as? Address)
        XCTAssertEqual(zeroAddress.address.lowercased(), "0x0000000000000000000000000000000000000000")

        let arrayValue = try XCTUnwrap(ParameterType.array(type: .bool, length: 2).emptyValue as? [Any])
        XCTAssertEqual(arrayValue.compactMap { $0 as? Bool }, [false, false])

        let tupleValue = try XCTUnwrap(ParameterType.tuple(types: [.address]).emptyValue as? [Any])
        XCTAssertTrue(tupleValue.isEmpty)
    }

    func testParameterTypeABIRepresentationAndValidation_whenTypesVary_thenMatchContracts() {
        XCTAssertEqual(ParameterType.uint(bits: 256).abiRepresentation, "uint256")
        XCTAssertEqual(ParameterType.int(bits: 64).abiRepresentation, "int64")
        XCTAssertEqual(ParameterType.address.abiRepresentation, "address")
        XCTAssertEqual(ParameterType.bool.abiRepresentation, "bool")
        XCTAssertEqual(ParameterType.bytes(length: 32).abiRepresentation, "bytes32")
        XCTAssertEqual(ParameterType.dynamicBytes.abiRepresentation, "bytes")
        XCTAssertEqual(ParameterType.function.abiRepresentation, "function")
        XCTAssertEqual(ParameterType.string.abiRepresentation, "string")
        XCTAssertEqual(ParameterType.array(type: .uint(bits: 32), length: 0).abiRepresentation, "uint32[]")
        XCTAssertEqual(ParameterType.array(type: .bool, length: 2).abiRepresentation, "bool[2]")
        XCTAssertEqual(
            ParameterType.tuple(types: [.address, .array(type: .bytes(length: 4), length: 2)]).abiRepresentation,
            "tuple(address,bytes4[2])"
        )

        XCTAssertTrue(ParameterType.uint(bits: 256).isValid)
        XCTAssertTrue(ParameterType.int(bits: 8).isValid)
        XCTAssertTrue(ParameterType.bytes(length: 32).isValid)
        XCTAssertTrue(ParameterType.array(type: .bool, length: 0).isValid)
        XCTAssertTrue(ParameterType.tuple(types: [.address, .string]).isValid)

        XCTAssertFalse(ParameterType.uint(bits: 7).isValid)
        XCTAssertFalse(ParameterType.int(bits: 264).isValid)
        XCTAssertFalse(ParameterType.bytes(length: 0).isValid)
        XCTAssertFalse(ParameterType.bytes(length: 33).isValid)
        XCTAssertFalse(ParameterType.array(type: .uint(bits: 7), length: 1).isValid)
        XCTAssertFalse(ParameterType.tuple(types: [.address, .bytes(length: 33)]).isValid)
    }

    func testElementSignatures_whenFunctionAndEventProvided_thenUseCanonicalABIRepresentation() {
        let transferInputs = [
            ABI.Element.InOut(name: "to", type: .address),
            ABI.Element.InOut(name: "value", type: .uint(bits: 256))
        ]
        let function = ABI.Element.Function(
            name: "transfer",
            inputs: transferInputs,
            outputs: [ABI.Element.InOut(name: "success", type: .bool)],
            constant: false,
            payable: false
        )

        XCTAssertEqual(function.signature, "transfer(address,uint256)")
        XCTAssertEqual(function.methodString, "a9059cbb")
        XCTAssertEqual(function.methodEncoding, Data([0xA9, 0x05, 0x9C, 0xBB]))

        let event = ABI.Element.Event(
            name: "Transfer",
            inputs: [
                ABI.Element.Event.Input(name: "from", type: .address, indexed: true),
                ABI.Element.Event.Input(name: "to", type: .address, indexed: true),
                ABI.Element.Event.Input(name: "value", type: .uint(bits: 256), indexed: false)
            ],
            anonymous: false
        )

        XCTAssertEqual(event.signature, "Transfer(address,address,uint256)")
        XCTAssertEqual(event.topic.count, 32)
        XCTAssertEqual(event.topic.prefix(4), Data([0xDD, 0xF2, 0x52, 0xAD]))
    }
}

final class ABIElementEncodingDecodingTests: XCTestCase {
    private let recipient = Address(address: "0x1111111111111111111111111111111111111111")!

    func testStateMutability_whenFlagsQueried_thenReflectsABIContractBehavior() {
        XCTAssertFalse(ABI.Element.StateMutability.payable.isConstant)
        XCTAssertFalse(ABI.Element.StateMutability.mutating.isConstant)
        XCTAssertTrue(ABI.Element.StateMutability.view.isConstant)
        XCTAssertTrue(ABI.Element.StateMutability.pure.isConstant)

        XCTAssertTrue(ABI.Element.StateMutability.payable.isPayable)
        XCTAssertFalse(ABI.Element.StateMutability.mutating.isPayable)
        XCTAssertFalse(ABI.Element.StateMutability.view.isPayable)
        XCTAssertFalse(ABI.Element.StateMutability.pure.isPayable)
    }

    func testEncodeParameters_whenFunctionAndConstructorProvided_thenEncodesCanonicalPayloads() throws {
        let function = transferFunction()
        let encodedFunction = try XCTUnwrap(
            ABI.Element.function(function).encodeParameters([recipient as AnyObject, BigUInt(7) as AnyObject])
        )

        XCTAssertEqual(encodedFunction.prefix(4), function.methodEncoding)
        XCTAssertEqual(encodedFunction.count, 68)

        let constructor = ABI.Element.Constructor(
            inputs: [ABI.Element.InOut(name: "owner", type: .address)],
            constant: false,
            payable: true
        )
        let encodedConstructor = try XCTUnwrap(
            ABI.Element.constructor(constructor).encodeParameters([recipient as AnyObject])
        )

        XCTAssertEqual(encodedConstructor.count, 32)
        XCTAssertNil(ABI.Element.function(function).encodeParameters([recipient as AnyObject]))
        XCTAssertNil(ABI.Element.event(transferEvent()).encodeParameters([]))
        XCTAssertNil(ABI.Element.fallback(.init(constant: false, payable: false)).encodeParameters([]))
    }

    func testDecodeInputData_whenPayloadsVary_thenValidatesSignaturesAndMapsNames() throws {
        let function = transferFunction()
        let element = ABI.Element.function(function)
        let encoded = try XCTUnwrap(
            element.encodeParameters([recipient as AnyObject, BigUInt(7) as AnyObject])
        )

        let decoded = try XCTUnwrap(element.decodeInputData(encoded))
        XCTAssertEqual(decoded["to"] as? Address, recipient)
        XCTAssertEqual(decoded["0"] as? Address, recipient)
        XCTAssertEqual(decoded["value"] as? BigUInt, BigUInt(7))
        XCTAssertEqual(decoded["1"] as? BigUInt, BigUInt(7))

        let wrongSignaturePayload = Data([0, 0, 0, 0]) + encoded.dropFirst(4)
        XCTAssertNil(element.decodeInputData(wrongSignaturePayload))
        XCTAssertNil(element.decodeInputData(Data(repeating: 0, count: 32)))
        XCTAssertNil(element.decodeInputData(Data([0x01])))

        let constructorInput = ABI.Element.Constructor(
            inputs: [ABI.Element.InOut(name: "enabled", type: .bool)],
            constant: false,
            payable: false
        )
        let constructor = ABI.Element.constructor(constructorInput)
        let encodedConstructorInput = try XCTUnwrap(
            constructor.encodeParameters([true as AnyObject])
        )
        let decodedConstructorInput = try XCTUnwrap(constructor.decodeInputData(encodedConstructorInput))
        XCTAssertEqual(decodedConstructorInput["enabled"] as? Bool, true)
        XCTAssertEqual(decodedConstructorInput["0"] as? Bool, true)

        let emptyConstructorInput = try XCTUnwrap(constructor.decodeInputData(Data()))
        XCTAssertEqual(emptyConstructorInput["enabled"] as? Bool, false)

        let singleInputFunction = ABI.Element.function(.init(
            name: "setPaused",
            inputs: [ABI.Element.InOut(name: "paused", type: .bool)],
            outputs: [],
            constant: false,
            payable: false
        ))
        let emptyFunctionInput = try XCTUnwrap(singleInputFunction.decodeInputData(Data()))
        XCTAssertEqual(emptyFunctionInput["paused"] as? Bool, false)
        XCTAssertEqual(emptyFunctionInput["0"] as? Bool, false)

        XCTAssertNil(ABI.Element.event(transferEvent()).decodeInputData(encoded))
        XCTAssertNil(ABI.Element.fallback(.init(constant: false, payable: false)).decodeInputData(encoded))
    }

    func testDecodeReturnData_whenFunctionReturnsValues_thenMapsIndexesAndNames() throws {
        let function = transferFunction()
        let element = ABI.Element.function(function)
        let encodedReturn = try XCTUnwrap(
            ABIEncoder.encode(types: function.outputs, values: [true as AnyObject])
        )

        let decodedReturn = try XCTUnwrap(element.decodeReturnData(encodedReturn))
        XCTAssertEqual(decodedReturn["success"] as? Bool, true)
        XCTAssertEqual(decodedReturn["0"] as? Bool, true)

        let emptyReturn = try XCTUnwrap(element.decodeReturnData(Data()))
        XCTAssertEqual(emptyReturn["success"] as? Bool, false)
        XCTAssertEqual(emptyReturn["0"] as? Bool, false)

        XCTAssertNil(element.decodeReturnData(Data([0x01])))
        XCTAssertNil(ABI.Element.constructor(.init(inputs: [], constant: false, payable: false)).decodeReturnData(encodedReturn))
        XCTAssertNil(ABI.Element.event(transferEvent()).decodeReturnData(encodedReturn))
        XCTAssertNil(ABI.Element.fallback(.init(constant: false, payable: false)).decodeReturnData(encodedReturn))
    }

    func testDecodeReturnedLogs_whenTransferEventProvided_thenMapsIndexedAndDataValues() throws {
        let event = transferEvent()
        let indexedAddress = try XCTUnwrap(
            ABIEncoder.encodeSingleType(type: .address, value: recipient as AnyObject)
        )
        let amountData = try XCTUnwrap(
            ABIEncoder.encode(types: [.uint(bits: 256)], values: [BigUInt(100) as AnyObject])
        )

        let decoded = try XCTUnwrap(
            event.decodeReturnedLogs(eventLogTopics: [event.topic, indexedAddress], eventLogData: amountData)
        )

        XCTAssertEqual(decoded["name"] as? String, "Transfer")
        XCTAssertEqual(decoded["from"] as? Address, recipient)
        XCTAssertEqual(decoded["0"] as? Address, recipient)
        XCTAssertEqual(decoded["value"] as? BigUInt, BigUInt(100))
        XCTAssertEqual(decoded["1"] as? BigUInt, BigUInt(100))

        let wrongTopic = Data(repeating: 1, count: 32)
        XCTAssertNil(event.decodeReturnedLogs(eventLogTopics: [wrongTopic, indexedAddress], eventLogData: amountData))
        XCTAssertNil(event.decodeReturnedLogs(eventLogTopics: [event.topic], eventLogData: amountData))
        XCTAssertNil(event.decodeReturnedLogs(eventLogTopics: [], eventLogData: amountData))
    }

    private func transferFunction() -> ABI.Element.Function {
        ABI.Element.Function(
            name: "transfer",
            inputs: [
                ABI.Element.InOut(name: "to", type: .address),
                ABI.Element.InOut(name: "value", type: .uint(bits: 256))
            ],
            outputs: [ABI.Element.InOut(name: "success", type: .bool)],
            constant: false,
            payable: false
        )
    }

    private func transferEvent() -> ABI.Element.Event {
        ABI.Element.Event(
            name: "Transfer",
            inputs: [
                ABI.Element.Event.Input(name: "from", type: .address, indexed: true),
                ABI.Element.Event.Input(name: "value", type: .uint(bits: 256), indexed: false)
            ],
            anonymous: false
        )
    }
}

final class BigIntABITests: XCTestCase {
    func testTwosComplement_whenPositiveAndNegativeValuesProvided_thenEncodesExpectedBytes() {
        XCTAssertEqual(BigInt(42).toTwosComplement(), Data([0x2A]))
        XCTAssertEqual(BigInt(-1).toTwosComplement(), Data([0xFF]))
        XCTAssertEqual(BigInt(-2).toTwosComplement(), Data([0xFE]))
        XCTAssertEqual(BigInt(-128).toTwosComplement(), Data([0x80]))
    }

    func testABIEncode_whenBigUIntAndBigIntProvided_thenPadsToRequestedBitWidth() throws {
        let encodedUInt = try XCTUnwrap(BigUInt(42).abiEncode(bits: 256))
        XCTAssertEqual(encodedUInt.count, 32)
        XCTAssertEqual(encodedUInt.prefix(31), Data(repeating: 0, count: 31))
        XCTAssertEqual(encodedUInt.last, 0x2A)

        XCTAssertEqual(try XCTUnwrap(BigInt(1).abiEncode(bits: 16)), Data([0x00, 0x01]))
        XCTAssertEqual(try XCTUnwrap(BigInt(-1).abiEncode(bits: 16)), Data([0xFF, 0xFF]))
        XCTAssertEqual(try XCTUnwrap(BigInt(-2).abiEncode(bits: 16)), Data([0xFF, 0xFE]))
    }

    func testFromTwosComplement_whenBytesProvided_thenRestoresSignedIntegers() {
        XCTAssertEqual(BigInt.fromTwosComplement(data: Data([0x00, 0x2A])), BigInt(42))
        XCTAssertEqual(BigInt.fromTwosComplement(data: Data([0xFF])), BigInt(-1))
        XCTAssertEqual(BigInt.fromTwosComplement(data: Data([0xFF, 0xFE])), BigInt(-2))
        XCTAssertEqual(BigInt.fromTwosComplement(data: Data([0x80])), BigInt(-128))
    }
}
