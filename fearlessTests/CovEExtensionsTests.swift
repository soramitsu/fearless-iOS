@testable import fearless
import BigInt
import ImageIO
import RobinHood
import SoraFoundation
import SoraKeystore
import SSFModels
import UIKit
import XCTest

/// Foundation and UIKit extensions from `Common/Extension`: input/output pairs and edge cases.
final class CovEExtensionsTests: XCTestCase {
    func testSafeDictionaryReadsWritesAndIterates() {
        let dictionary = SafeDictionary<String, Int>(dict: ["a": 1])
        dictionary["b"] = 2
        XCTAssertEqual(dictionary["b"], 2, "Barrier writes are visible to the next read")
        XCTAssertEqual(Set(dictionary.keys), ["a", "b"])
        XCTAssertEqual(Set(dictionary.values), [1, 2])
        XCTAssertEqual(dictionary.count, 2)
        let index = dictionary.startIndex
        XCTAssertNotEqual(index, dictionary.endIndex)
        XCTAssertTrue(["a", "b"].contains(dictionary[index].key))
        XCTAssertEqual(dictionary.index(after: dictionary.index(after: index)), dictionary.endIndex)
        XCTAssertEqual(Set(dictionary.map(\.value)), [1, 2])
        dictionary.removeValue(forKey: "a")
        XCTAssertNil(dictionary["a"])
        dictionary.replace(dict: ["x": 9, "y": 8])
        XCTAssertEqual(dictionary["x"], 9, "Reads wait for the pending replacement")
        XCTAssertEqual(dictionary.dictionary, ["x": 9, "y": 8])
        dictionary.removeAll()
        XCTAssertTrue(dictionary.isEmpty)
        XCTAssertTrue(SafeDictionary<Int, Int>().isEmpty)
    }

    func testDebounceRunsOnlyTheLastCallAndThrottleRunsOncePerWindow() {
        var plain = 0
        var single: [Int] = []
        var pairs: [String] = []
        let debounced = debounce(delay: .milliseconds(30)) { plain += 1 }
        let debounced1 = debounce1(delay: .milliseconds(30)) { (value: Int) in single.append(value) }
        let debounced2 = debounce2(delay: .milliseconds(30)) { (left: String, right: Int) in pairs.append("\(left)\(right)") }
        for value in 0 ..< 5 {
            debounced()
            debounced1(value)
            debounced2("d", value)
        }
        XCTAssertTrue(spin { plain == 1 && single == [4] && pairs == ["d4"] }, "Only the last call survives a burst")

        var throttled = 0
        var throttledSingle: [Int] = []
        var throttledPairs: [String] = []
        let throttle0 = throttle(delay: 0.05) { throttled += 1 }
        let throttle1Fn = throttle1(delay: 0.05) { (value: Int) in throttledSingle.append(value) }
        let throttle2Fn = throttle2(delay: 0.05) { (left: String, right: Int) in throttledPairs.append("\(left)\(right)") }
        for value in 0 ..< 3 {
            throttle0()
            throttle1Fn(value)
            throttle2Fn("t", value)
        }
        XCTAssertTrue(spin { throttled == 1 && throttledSingle == [0] && throttledPairs == ["t0"] }, "The first call of a window wins")
        throttle0()
        throttle1Fn(7)
        throttle2Fn("t", 7)
        XCTAssertTrue(spin { throttled == 2 && throttledSingle == [0, 7] && throttledPairs == ["t0", "t7"] }, "A later call is delayed, not dropped")
        XCTAssertTrue(TimeInterval(0).hasPassed(since: 1))
        XCTAssertFalse(Date().timeIntervalSinceReferenceDate.hasPassed(since: 60))
    }

    func testVersionComparison() {
        XCTAssertTrue("1.2.3".versionLowerThan("1.3.0"))
        XCTAssertTrue("1.2.3".versionLowerThan("2.0"))
        XCTAssertTrue("4.2.0".versionLowerThan("4.2.1"))
        XCTAssertFalse("4.2.1".versionLowerThan("4.2.0"))
        XCTAssertFalse("4.2.1".versionLowerThan("4.2.1"), "Equal versions are not lower")
        XCTAssertFalse("4.2".versionLowerThan("4.2.1"), "Only the shared components are compared")
        XCTAssertFalse("3.0".versionLowerThan("2.9"))
        XCTAssertFalse("1.0".versionLowerThan(nil))
        XCTAssertFalse("x.1".versionLowerThan("1.0"), "Non-numeric components never compare lower")
        XCTAssertFalse("1.x".versionLowerThan("1.2"))
    }

    func testAsyncSequenceHelpers() async throws {
        let values = [1, 2, 3, 4]
        let mapped = await values.asyncMap { $0 % 2 == 0 ? $0 * 10 : nil }
        XCTAssertEqual(mapped, [20, 40])
        let compact = await values.asyncCompactMap { $0 > 2 ? "\($0)" : nil }
        XCTAssertEqual(compact, ["3", "4"])
        let sum = await values.asyncReduce(0) { $0 + $1 }
        XCTAssertEqual(sum, 10)
        var visited: [Int] = []
        await values.asyncForEach { visited.append($0) }
        XCTAssertEqual(visited, values)
        let concurrent = try await values.concurrentMap { $0 == 3 ? nil : $0 * 2 }
        XCTAssertEqual(concurrent, [2, 4, 8], "Concurrent results keep input order and drop nils")
    }

    func testNumberFormatterPresets() {
        let en = Locale(identifier: "en_US")
        func string(_ formatter: NumberFormatter, _ value: Double) -> String? {
            formatter.locale = en
            return formatter.string(from: NSNumber(value: value))
        }
        XCTAssertEqual(string(.amount, 1234.5), "1,234.5")
        XCTAssertEqual(string(.percent, 0.1234), "12.34%")
        XCTAssertEqual(string(.percentPlain, 12.345), "12.34%")
        XCTAssertEqual(string(.signedPercent, 0.05), "+5%")
        XCTAssertEqual(string(.percentPlainAPY, 7.5), "7.50% APY")
        XCTAssertEqual(string(.percentAPY, 0.075), "7.50% APY")
        XCTAssertEqual(string(.positivePercentAPY, 0.075), "+7.50% APY")
        XCTAssertEqual(string(.positivePercentAPR, 0.075), "+7.50% APR")
        XCTAssertEqual(string(.percentSingle, 0.5), "50%")
        XCTAssertEqual(string(.quantity, 1234.56), "1,235")
        XCTAssertEqual(string(.fiat, 1234.5678), "1,234.56")
        XCTAssertEqual(string(.polkaswapBalance, 1.234567), "1.2345")
        XCTAssertEqual(string(.token(rounding: .down), 1.5), "1.500")
        XCTAssertEqual(string(.token(rounding: .up, usesIntGrouping: true), 12345.123456789), "12,345.12345679")
    }

    func testNumberFormatterUsageCases() {
        let en = Locale(identifier: "en_US")
        func string(_ usage: NumberFormatterUsageCase, _ value: Double, rounding: NumberFormatter.RoundingMode = .down) -> String? {
            NumberFormatter.formatter(for: usage, locale: en, rounding: rounding).string(from: NSNumber(value: value))
        }
        let list = NumberFormatter.formatter(for: .listCrypto, locale: en, rounding: .up, usesIntGrouping: true)
        XCTAssertEqual([list.minimumFractionDigits, list.maximumFractionDigits], [3, 8])
        XCTAssertEqual(list.roundingMode, .up)
        XCTAssertTrue(list.usesGroupingSeparator)
        let custom = NumberFormatter.formatter(for: .listCryptoWith(minimumFractionDigits: 1, maximumFractionDigits: 2), locale: en)
        XCTAssertEqual([custom.minimumFractionDigits, custom.maximumFractionDigits], [1, 2])
        let details = NumberFormatter.formatter(for: .detailsCrypto, locale: en)
        XCTAssertEqual([details.minimumFractionDigits, details.maximumFractionDigits], [0, 8])
        XCTAssertEqual(NumberFormatter.formatter(for: .exactCrypto(fractionDigits: 3), locale: en).maximumFractionDigits, 3)
        XCTAssertEqual(NumberFormatter.formatter(for: .exactCrypto(fractionDigits: 99), locale: en).maximumFractionDigits, 38, "Fraction digits are clamped")
        XCTAssertEqual(NumberFormatter.formatter(for: .exactCrypto(fractionDigits: -2), locale: en).maximumFractionDigits, 0)
        XCTAssertEqual(details.locale, en)
        XCTAssertEqual(string(.fiat, 1234.5), "1,234.5")
        XCTAssertEqual(string(.percent, 0.4567), "45.67%")
        XCTAssertEqual(string(.inputCrypto, 0.123456789), "0.12345678")
        XCTAssertEqual(string(.inputFiat, 1234.567), "1,234.56")
        let decimal = NumberFormatter.decimalFormatter(precision: 2, rounding: .up, usesIntGrouping: true, usageCase: .listCrypto, locale: en)
        XCTAssertEqual(decimal.string(from: 1234.0001), "1,234.0001")
        XCTAssertEqual(decimal.numberStyle, .decimal)
    }

    func testDateFormatters() {
        let locale = Locale(identifier: "en_US")
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(DateFormatter.iso.string(from: date), "2023-11-14T22:13:20.000Z")
        XCTAssertEqual(DateFormatter.giantsquidDate.value(for: locale).string(from: date), "2023-11-14T22:13:20.000000+0000")
        XCTAssertEqual(DateFormatter.suibsquidInputDate.value(for: locale).string(from: date), "2023-11-14T22:13:20.000000Z")
        XCTAssertEqual(DateFormatter.alchemyDate.value(for: locale).date(from: "2023-11-14T22:13:20.000Z"), date)
        for formatter in [DateFormatter.txHistory, DateFormatter.txDetails, DateFormatter.shortDate, DateFormatter.sectionedDate, DateFormatter.connectionExpiry] {
            let value = formatter.value(for: locale)
            XCTAssertEqual(value.locale, locale)
            XCTAssertFalse(value.string(from: date).isEmpty)
        }
        XCTAssertTrue(DateFormatter.shortDate.value(for: locale).string(from: date).contains("2023"))
    }

    func testGifDecodingCollectsFramesAndDelays() throws {
        let data = try makeGif(delays: [0.1, 0.25])
        let gif = try XCTUnwrap(UIImage.makeGIFFromData(data: data, repeatCount: 3))
        XCTAssertEqual(gif.images.count, 2)
        XCTAssertEqual(gif.durationInSec, 0.35, accuracy: 0.011)
        XCTAssertEqual(gif.repeatCount, 3)
        XCTAssertNil(UIImage.makeGIFFromData(data: Data([1, 2, 3]))?.images.first)
        XCTAssertNil(UIImage.makeGIFFromCollection(name: "covE-missing-gif"))
        let png = try XCTUnwrap(R.image.iconClose()?.pngData())
        let source = try XCTUnwrap(CGImageSourceCreateWithData(png as CFData, nil))
        XCTAssertEqual(UIImage.delayForImageAtIndex(0, source: source), 0, "Non-GIF frames have no delay")
        let imageView = UIImageView()
        imageView.setGIFImage(name: "covE-missing-gif")
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertNil(imageView.animationImages, "A missing resource leaves the view untouched")
    }

    func testAccountOptionsSheetListsExplorersAndRunsClosures() {
        let explorers = [
            ChainModel.ExternalApiExplorer(type: .subscan, types: [.address], url: "https://example.invalid/{type}/{value}"),
            ChainModel.ExternalApiExplorer(type: .polkascan, types: [.address], url: "")
        ]
        let chain = ChainModel(
            rank: nil, disabled: false, chainId: "covE", parentId: nil, paraId: nil, name: "CovE", xcm: nil,
            nodes: [], addressPrefix: 0, types: nil, icon: nil, options: nil,
            externalApi: ChainModel.ExternalApiSet(explorers: explorers),
            selectedNode: nil, customNodes: nil, iosMinAppVersion: nil, identityChain: nil
        )
        var events: [String] = []
        let locale = Locale(identifier: "en")
        let sheet = UIAlertController.presentAccountOptions(
            "ABCDEF", chain: chain, locale: locale,
            copyClosure: { events.append("copy") },
            urlClosure: { events.append($0.absoluteString) },
            exportClosure: { events.append("export") }
        )
        XCTAssertEqual(sheet.title, "ABC\nDEF")
        XCTAssertEqual(sheet.preferredStyle, .actionSheet)
        XCTAssertEqual(sheet.actions.map(\.title), [
            R.string.localizable.commonCopyAddress(preferredLanguages: locale.rLanguages),
            ChainModel.ExternalApiExplorerType.subscan.actionTitle().value(for: locale),
            R.string.localizable.commonExport(preferredLanguages: locale.rLanguages),
            R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        ])
        XCTAssertEqual(sheet.actions.last?.style, .cancel)
        for action in sheet.actions.dropLast() {
            CovEAlert.tap(action)
        }
        XCTAssertEqual(events, ["copy", "https://example.invalid/address/ABCDEF", "export"])
        let withoutExport = UIAlertController.presentAccountOptions(
            "XY", chain: chain, locale: locale, copyClosure: {}, urlClosure: { _ in }
        )
        XCTAssertEqual(withoutExport.actions.count, 3)
    }

    func testImageDrawingHelpers() throws {
        let background = try XCTUnwrap(UIImage.background(from: .red, size: CGSize(width: 4, height: 2), cornerRadius: 1, contentScale: 2))
        XCTAssertEqual(background.size, CGSize(width: 4, height: 2))
        XCTAssertEqual(background.scale, 2)
        let source = try XCTUnwrap(UIImage.background(from: .blue, size: CGSize(width: 40, height: 20)))
        let cropped = try XCTUnwrap(source.crop(targetSize: CGSize(width: 10, height: 10), cornerRadius: 2, contentScale: 1))
        XCTAssertEqual(cropped.size, CGSize(width: 10, height: 10))
        let tall = try XCTUnwrap(UIImage.background(from: .blue, size: CGSize(width: 10, height: 40)))
        XCTAssertEqual(tall.crop(targetSize: CGSize(width: 20, height: 10), cornerRadius: 0, contentScale: 1)?.size, CGSize(width: 20, height: 10))
        XCTAssertNil(source.crop(targetSize: .zero, cornerRadius: 0, contentScale: 1))
        XCTAssertNil(UIImage().crop(targetSize: CGSize(width: 1, height: 1), cornerRadius: 0, contentScale: 1))
        let tinted = try XCTUnwrap(source.tinted(with: .green))
        XCTAssertEqual(tinted.size, source.size)
    }
}

extension CovEExtensionsTests {
    func testPredicatesMatchTheirKeys() {
        let record: [String: Any] = [
            "sender": "alice", "receiver": "bob", "targetAddress": "carol", "identifier": "id-1",
            "stash": "s", "controller": "c", "isSelected": true, "chainId": "dot", "hasCrowdloans": true, "disabled": false
        ]
        let object = record as NSDictionary
        XCTAssertTrue(NSPredicate.filterTransactionsBy(address: "bob").evaluate(with: object))
        XCTAssertTrue(NSPredicate.filterTransactionsBy(address: "alice").evaluate(with: object))
        XCTAssertFalse(NSPredicate.filterTransactionsBy(address: "dave").evaluate(with: object))
        XCTAssertTrue(NSPredicate.filterContactsByTarget(address: "carol").evaluate(with: object))
        XCTAssertTrue(NSPredicate.filterRuntimeMetadataItemsBy(identifier: "id-1").evaluate(with: object))
        XCTAssertTrue(NSPredicate.filterStorageItemsBy(identifier: "id-1").evaluate(with: object))
        XCTAssertTrue(NSPredicate.filterByIdPrefix("id-").evaluate(with: object))
        XCTAssertTrue(NSPredicate.filterByStash("s").evaluate(with: object))
        XCTAssertTrue(NSPredicate.filterByStashOrController("c").evaluate(with: object))
        XCTAssertTrue(NSPredicate.selectedMetaAccount().evaluate(with: object))
        XCTAssertTrue(NSPredicate.relayChains().evaluate(with: object))
        XCTAssertTrue(NSPredicate.chainBy(identifier: "dot").evaluate(with: object))
        XCTAssertTrue(NSPredicate.hasCrowloans().evaluate(with: object))
        XCTAssertTrue(NSPredicate.enabledCHain().evaluate(with: object))
        let accountId = Data(repeating: 1, count: 32)
        let compound = NSPredicate.filterAccountItemByAccountId(accountId) as? NSCompoundPredicate
        XCTAssertEqual(compound?.compoundPredicateType, .or)
        XCTAssertGreaterThanOrEqual(compound?.subpredicates.count ?? 0, 3)
    }

    func testSettingsAccessorsStoreAndClearValues() {
        let settings = InMemorySettingsManager()
        XCTAssertNil(settings.biometryEnabled)
        settings.biometryEnabled = true
        XCTAssertEqual(settings.biometryEnabled, true)
        settings.biometryEnabled = nil
        XCTAssertNil(settings.biometryEnabled)
        settings.crowdloanChainId = "dot"
        XCTAssertEqual(settings.crowdloanChainId, "dot")
        settings.crowdloanChainId = nil
        XCTAssertNil(settings.crowdloanChainId)
        let asset = ChainAssetId(chainId: "dot", assetId: "dot-asset")
        settings.stakingAsset = asset
        XCTAssertEqual(settings.stakingAsset, asset)
        settings.stakingAsset = nil
        XCTAssertNil(settings.stakingAsset)
        XCTAssertTrue(settings.stakingNetworkExpansion, "Expansion defaults to on")
        settings.stakingNetworkExpansion = false
        XCTAssertFalse(settings.stakingNetworkExpansion)
        XCTAssertTrue(settings.shouldRunManageAssetAnimate)
        settings.shouldRunManageAssetAnimate = false
        XCTAssertFalse(settings.shouldRunManageAssetAnimate, "Any stored value means the animation already ran")
        XCTAssertEqual(settings.accountScoreEnabled, true)
        settings.accountScoreEnabled = false
        XCTAssertEqual(settings.accountScoreEnabled, false)
        settings.accountScoreEnabled = nil
        XCTAssertEqual(settings.accountScoreEnabled, true)
        settings.acknowledgedRecordsNotShown = "hash"
        XCTAssertEqual(settings.acknowledgedRecordsNotShown, "hash")
        settings.acknowledgedRecordsNotShown = nil
        XCTAssertNil(settings.acknowledgedRecordsNotShown)
        XCTAssertEqual(settings.acknowledgedStoredChainAccounts, [])
        settings.acknowledgedStoredChainAccounts = ["a", "b"]
        XCTAssertEqual(settings.acknowledgedStoredChainAccounts, ["a", "b"])
    }

    func testDataProviderChangeHelpers() {
        let first = CovEIdentified(identifier: "1", value: 1)
        let changed = CovEIdentified(identifier: "1", value: 2)
        XCTAssertNil(DataProviderChange<CovEIdentified>.change(value1: CovEIdentified?.none, value2: CovEIdentified?.none))
        XCTAssertEqual(DataProviderChange<CovEIdentified>.change(value1: nil, value2: first)?.item, first)
        XCTAssertNil(DataProviderChange<CovEIdentified>.change(value1: first, value2: nil)?.item)
        if case let .delete(identifier) = DataProviderChange<CovEIdentified>.change(value1: first, value2: nil) {
            XCTAssertEqual(identifier, "1")
        } else {
            XCTFail("A removed value is a deletion")
        }
        XCTAssertEqual(DataProviderChange<CovEIdentified>.change(value1: first, value2: changed)?.item, changed)
        XCTAssertNil(DataProviderChange<CovEIdentified>.change(value1: first, value2: first), "Equal values are no change")

        let changes: [DataProviderChange<CovEIdentified>] = [.insert(newItem: first), .update(newItem: changed)]
        XCTAssertEqual(changes.reduceToLastChange(), changed)
        XCTAssertNil((changes + [.delete(deletedIdentifier: "1")]).reduceToLastChange())
        XCTAssertEqual(changes.firstToLastChange { $0.value == 2 }, changed)
        XCTAssertNil([DataProviderChange<CovEIdentified>.delete(deletedIdentifier: "1")].firstToLastChange { _ in true })
    }

    func testTimeIntervalDecimalAndStringHelpers() {
        let locale = Locale(identifier: "en")
        XCTAssertEqual(TimeInterval(1.5).milliseconds, 1500)
        XCTAssertEqual(TimeInterval(1500).seconds, 1.5)
        XCTAssertEqual((TimeInterval.secondsInDay * 2).daysFromSeconds, 2)
        XCTAssertEqual((TimeInterval.secondsInHour * 5).hoursFromSeconds, 5)
        XCTAssertEqual(TimeInterval.secondsInHour.intervalsInDay, 24)
        XCTAssertEqual(TimeInterval(0).intervalsInDay, 0)
        XCTAssertEqual(TimeInterval.secondsInMonth, TimeInterval.secondsInWeek * 30)
        XCTAssertEqual(
            (TimeInterval.secondsInDay * 3).readableValue(locale: locale),
            R.string.localizable.commonDaysFormat(format: 3, preferredLanguages: locale.rLanguages)
        )
        XCTAssertEqual(
            (TimeInterval.secondsInHour * 4).readableValue(locale: locale),
            R.string.localizable.commonHoursFormat(format: 4, preferredLanguages: locale.rLanguages)
        )
        XCTAssertEqual(
            (TimeInterval.secondsInDay * 2).localizedReadableValue().value(for: locale),
            R.string.localizable.commonDaysFormat(format: 2, preferredLanguages: locale.rLanguages)
        )
        XCTAssertEqual(
            (TimeInterval.secondsInHour * 7).localizedReadableValue().value(for: locale),
            R.string.localizable.commonHoursFormat(format: 7, preferredLanguages: locale.rLanguages)
        )

        XCTAssertEqual(Decimal(string: "1.000234")?.string(maximumFractionDigits: 2), "1.00023")
        XCTAssertEqual(Decimal(string: "12.5")?.string(), "12.5")
        XCTAssertEqual(Decimal(7).string(), "7")
        XCTAssertEqual(Decimal(string: "0.123")?.string(maximumFractionDigits: 1), "0.1")

        XCTAssertEqual("transfer_keep_alive".displayCall, "Transfer Keep Alive")
        XCTAssertEqual("nominationPools".displayModule, "Nomination Pools")
        XCTAssertEqual("a_b".replacingSnakeCase(), "a b")
        XCTAssertEqual("aBc".replacingCamelCase(), "a Bc")

        XCTAssertEqual(String.returnKey, "\n")
        XCTAssertEqual("x".underlined.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int, NSUnderlineStyle.single.rawValue)
        let font = UIFont.systemFont(ofSize: 14)
        XCTAssertGreaterThan("Hello".widthOfString(usingFont: font), 0)
        XCTAssertGreaterThan("Hello".heightOfString(usingFont: font), 0)
        XCTAssertEqual("Hello".sizeOfString(usingFont: font).width, "Hello".widthOfString(usingFont: font))
        XCTAssertGreaterThan(String(repeating: "word ", count: 40).height(withConstrainedWidth: 100, font: font), "word".height(withConstrainedWidth: 100, font: font))
    }

    @MainActor
    func testBarButtonStyleAndTopViewControllerLookup() {
        let item = UIBarButtonItem(title: "Done", style: .plain, target: nil, action: nil)
        item.setupDefaultTitleStyle()
        XCTAssertEqual(item.titleTextAttributes(for: .normal)?[.font] as? UIFont, .h5Title)
        XCTAssertEqual(item.titleTextAttributes(for: .highlighted)?[.foregroundColor] as? UIColor, R.color.colorGray())
        XCTAssertEqual(item.titleTextAttributes(for: .disabled)?[.foregroundColor] as? UIColor, R.color.colorDarkGray())

        let leaf = UIViewController()
        let navigation = UINavigationController(rootViewController: leaf)
        XCTAssertTrue(UIApplication.topViewController(controller: navigation) === leaf)
        let tabs = UITabBarController()
        let tabLeaf = UIViewController()
        tabs.viewControllers = [tabLeaf]
        tabs.selectedIndex = 0
        XCTAssertTrue(UIApplication.topViewController(controller: tabs) === tabLeaf)
        XCTAssertTrue(UIApplication.topViewController(controller: UITabBarController()) is UITabBarController)
        XCTAssertNil(UIApplication.topViewController(controller: nil))
        let plain = UIViewController()
        XCTAssertTrue(UIApplication.topViewController(controller: plain) === plain)
    }

    @MainActor
    func testSmallUIKitAndFoundationExtensions() throws {
        XCTAssertEqual(BigUInt.fromHexString("0xff"), 255)
        XCTAssertEqual(BigUInt.fromHexString("10"), 16)
        XCTAssertNil(BigUInt.fromHexString(nil))
        XCTAssertNil(BigUInt.fromHexString("0xzz"))
        XCTAssertEqual(BigUInt(4095).toHexString(), "0xfff")

        let divided = [1, 2, 3, 4, 5].divide { $0 % 2 == 0 }
        XCTAssertEqual(divided.slice, [2, 4])
        XCTAssertEqual(divided.remainder, [1, 3, 5])

        XCTAssertEqual(URL(string: "ipfs://QmHash/1.png")?.normalizedIpfsURL?.absoluteString, "https://ipfs.io/ipfs/QmHash/1.png")
        let https = try XCTUnwrap(URL(string: "https://example.invalid/ipfs/x"))
        XCTAssertEqual(https.normalizedIpfsURL, https, "TLS links are kept")
        let plain = try XCTUnwrap(URL(string: "http://example.invalid/a.png"))
        XCTAssertEqual(plain.normalizedIpfsURL, plain, "Non-IPFS links are kept")

        XCTAssertEqual(UIColor(red: 1, green: 0, blue: 0.5, alpha: 1).hexRGB, "#FF007F")
        XCTAssertEqual(UIColor(red: 0, green: 1, blue: 0, alpha: 0.5).hexRGBA, "#00FF007F")
        XCTAssertEqual(UIColor.red.rgbaComponents.red, 1)

        let content = AccountOperationFactoryError.decryption.toErrorContent(for: Locale(identifier: "en"))
        XCTAssertEqual(content.title, R.string.localizable.accountImportKeystoreDecryptionErrorTitle(preferredLanguages: ["en"]))
        let general = AccountOperationFactoryError.missingUsername.toErrorContent(for: nil)
        XCTAssertEqual(general.title, R.string.localizable.commonErrorGeneralTitle(preferredLanguages: nil))

        let button = UIButton(type: .custom)
        button.setTextAndImage(spacing: 8)
        XCTAssertEqual(button.imageEdgeInsets.left, -4)
        XCTAssertEqual(button.titleEdgeInsets.left, 4)
        button.semanticContentAttribute = .forceRightToLeft
        button.setTextAndImage(spacing: 8)
        XCTAssertEqual(button.imageEdgeInsets.left, 4, "Right-to-left mirrors the insets")

        let source = try XCTUnwrap(UIImage.background(from: .black, size: CGSize(width: 2, height: 2)))
        let inverted = try XCTUnwrap(source.invertedImage())
        XCTAssertEqual(inverted.size, source.size)
        XCTAssertNil(UIImage().invertedImage())

        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
        scroll.contentSize = CGSize(width: 400, height: 200)
        scroll.scrollTo(
            horizontalPage: UIScrollView.Page(intValue: 2, direction: .horizontal(offset: 0)),
            verticalPage: UIScrollView.Page(intValue: 1, direction: .vertical(offset: 10)),
            animated: false
        )
        XCTAssertEqual(scroll.contentOffset, CGPoint(x: 200, y: 60))
        XCTAssertEqual(UIScrollView.Page.Direction.vertical(offset: 3).offset, 3)

        let table = UITableView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let header = UILabel()
        header.text = "Header"
        table.setAndLayoutTableHeaderView(header: header)
        XCTAssertTrue(table.tableHeaderView === header)
        XCTAssertGreaterThan(header.frame.height, 0)

        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 40, height: 40)
        let collection = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 200), collectionViewLayout: layout)
        collection.registerClassForCell(CovECollectionCell.self)
        let dataSource = CovECollectionSource()
        collection.dataSource = dataSource
        collection.reloadData()
        collection.layoutIfNeeded()
        let cell = try XCTUnwrap(collection.cellForItem(at: IndexPath(item: 1, section: 0)))
        XCTAssertTrue(cell.usedCollectionView === collection)
        XCTAssertEqual(cell.indexPath, IndexPath(item: 1, section: 0))
        XCTAssertNil(CovECollectionCell().indexPath)
    }

    private func spin(timeout: TimeInterval = 2, until condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            if condition() {
                return true
            }
            if Date() > deadline {
                return condition()
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    private func makeGif(delays: [Double]) throws -> Data {
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, "com.compuserve.gif" as CFString, delays.count, nil))
        for (index, delay) in delays.enumerated() {
            let color: UIColor = index % 2 == 0 ? .red : .blue
            let frame = try XCTUnwrap(UIImage.background(from: color, size: CGSize(width: 2, height: 2))?.cgImage)
            let key = index == 0 ? kCGImagePropertyGIFDelayTime : kCGImagePropertyGIFUnclampedDelayTime
            let properties = [kCGImagePropertyGIFDictionary: [key: delay]] as CFDictionary
            CGImageDestinationAddImage(destination, frame, properties)
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
}

final class CovECollectionCell: UICollectionViewCell {}

final class CovECollectionSource: NSObject, UICollectionViewDataSource {
    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        3
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        collectionView.dequeueReusableCellWithType(CovECollectionCell.self, forIndexPath: indexPath)
    }
}

struct CovEIdentified: RobinHood.Identifiable, Equatable {
    let identifier: String
    let value: Int
}

enum CovEAlert {
    private typealias CovEHandler = @convention(block) (UIAlertAction) -> Void

    /// Runs an alert action's handler the way a tap would.
    static func tap(_ action: UIAlertAction) {
        guard let block = action.value(forKey: "handler") else { return }
        let handler = unsafeBitCast(block as AnyObject, to: CovEHandler.self)
        handler(action)
    }
}
