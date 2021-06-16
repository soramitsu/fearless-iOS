import Foundation
import CommonWallet
import SoraFoundation
import IrohaCrypto
import FearlessUtils

protocol CrowdloansViewModelFactoryProtocol {
    func createViewModel(
        from crowdloans: [Crowdloan],
        displayInfo: CrowdloanDisplayInfoDict?,
        metadata: CrowdloanMetadata,
        locale: Locale
    ) -> CrowdloansViewModel
}

final class CrowdloansViewModelFactory {
    struct CommonContent {
        let title: String
        let details: CrowdloanDescViewModel
        let progress: String
        let imageViewModel: ImageViewModelProtocol
    }

    struct Formatters {
        let token: TokenFormatter
        let quantity: NumberFormatter
        let display: LocalizableDecimalFormatting
        let time: TimeFormatterProtocol
    }

    let amountFormatterFactory: NumberFormatterFactoryProtocol
    let asset: WalletAsset
    let chain: Chain

    private lazy var addressFactory = SS58AddressFactory()
    private lazy var iconGenerator = PolkadotIconGenerator()

    private lazy var dateFormatter = {
        CompoundDateFormatterBuilder()
    }()

    init(amountFormatterFactory: NumberFormatterFactoryProtocol, asset: WalletAsset, chain: Chain) {
        self.amountFormatterFactory = amountFormatterFactory
        self.asset = asset
        self.chain = chain
    }

    private func createCommonContent(
        from model: Crowdloan,
        displayInfo: CrowdloanDisplayInfo?,
        formatters: Formatters,
        locale: Locale
    ) -> CommonContent? {
        guard let depositorAddress = try? addressFactory.addressFromAccountId(
            data: model.fundInfo.depositor,
            type: chain.addressType
        ) else {
            return nil
        }

        let title = displayInfo?.name ?? formatters.quantity.string(from: NSNumber(value: model.paraId))
        let details: CrowdloanDescViewModel = {
            if let desc = displayInfo?.description {
                return .text(desc)
            } else {
                return .address(depositorAddress)
            }
        }()

        let progress: String = {
            if
                let raised = Decimal.fromSubstrateAmount(model.fundInfo.raised, precision: asset.precision),
                let cap = Decimal.fromSubstrateAmount(model.fundInfo.cap, precision: asset.precision),
                let raisedString = formatters.display.stringFromDecimal(raised),
                let totalString = formatters.token.stringFromDecimal(cap) {
                return R.string.localizable.crowdloanProgressFormat(
                    raisedString,
                    totalString,
                    preferredLanguages: locale.rLanguages
                )
            } else {
                return ""
            }
        }()

        let iconViewModel: ImageViewModelProtocol = {
            if let urlString = displayInfo?.icon, let url = URL(string: urlString) {
                return RemoteImageViewModel(url: url)
            } else {
                let icon = try? iconGenerator.generateFromAddress(depositorAddress).imageWithFillColor(
                    R.color.colorWhite()!,
                    size: UIConstants.normalAddressIconSize,
                    contentScale: UIScreen.main.scale
                )

                return WalletStaticImageViewModel(staticImage: icon ?? UIImage())
            }

        }()

        return CommonContent(
            title: title ?? "",
            details: details,
            progress: progress,
            imageViewModel: iconViewModel
        )
    }

    private func createActiveCrowdloanViewModel(
        from model: Crowdloan,
        displayInfo: CrowdloanDisplayInfo?,
        metadata: CrowdloanMetadata,
        formatters: Formatters,
        locale: Locale
    ) -> ActiveCrowdloanViewModel? {
        guard !model.isCompleted(for: metadata) else {
            return nil
        }

        guard let commonContent = createCommonContent(
            from: model,
            displayInfo: displayInfo,
            formatters: formatters,
            locale: locale
        ) else {
            return nil
        }

        let timeLeft: String = {
            let remainedTime = model.remainedTime(
                at: metadata.blockNumber,
                blockDuration: metadata.blockDuration
            )

            if remainedTime.daysFromSeconds > 0 {
                return R.string.localizable.stakingPayoutsDaysLeft(
                    format: remainedTime.daysFromSeconds,
                    preferredLanguages: locale.rLanguages
                )
            } else {
                let time = try? formatters.time.string(from: remainedTime)
                return R.string.localizable.commonTimeLeftFormat(
                    time ?? "",
                    preferredLanguages: locale.rLanguages
                )
            }
        }()

        return ActiveCrowdloanViewModel(
            title: commonContent.title,
            timeleft: timeLeft,
            description: commonContent.details,
            progress: commonContent.progress,
            iconViewModel: commonContent.imageViewModel
        )
    }

    private func createCompletedCrowdloanViewModel(
        from model: Crowdloan,
        displayInfo: CrowdloanDisplayInfo?,
        metadata: CrowdloanMetadata,
        formatters: Formatters,
        locale: Locale
    ) -> CompletedCrowdloanViewModel? {
        guard model.isCompleted(for: metadata) else {
            return nil
        }

        guard let commonContent = createCommonContent(
            from: model,
            displayInfo: displayInfo,
            formatters: formatters,
            locale: locale
        ) else {
            return nil
        }

        return CompletedCrowdloanViewModel(
            title: commonContent.title,
            description: commonContent.details,
            progress: commonContent.progress,
            iconViewModel: commonContent.imageViewModel
        )
    }

    func createSections(
        from crowdloans: [Crowdloan],
        displayInfo: CrowdloanDisplayInfoDict?,
        metadata: CrowdloanMetadata,
        formatters: Formatters,
        locale: Locale
    ) -> ([CrowdloanActiveSection], [CrowdloanCompletedSection]) {
        let initial = (
            [CrowdloanActiveSection](),
            [CrowdloanCompletedSection]()
        )

        return crowdloans.reduce(into: initial) { result, crowdloan in
            if crowdloan.isCompleted(for: metadata) {
                if let viewModel = createCompletedCrowdloanViewModel(
                    from: crowdloan,
                    displayInfo: displayInfo?[crowdloan.paraId],
                    metadata: metadata,
                    formatters: formatters,
                    locale: locale
                ) {
                    let sectionItem = CrowdloanSectionItem(paraId: crowdloan.paraId, content: viewModel)
                    result.1.append(sectionItem)
                }
            } else {
                if let viewModel = createActiveCrowdloanViewModel(
                    from: crowdloan,
                    displayInfo: displayInfo?[crowdloan.paraId],
                    metadata: metadata,
                    formatters: formatters,
                    locale: locale
                ) {
                    let sectionItem = CrowdloanSectionItem(paraId: crowdloan.paraId, content: viewModel)
                    result.0.append(sectionItem)
                }
            }
        }
    }
}

extension CrowdloansViewModelFactory: CrowdloansViewModelFactoryProtocol {
    func createViewModel(
        from crowdloans: [Crowdloan],
        displayInfo: CrowdloanDisplayInfoDict?,
        metadata: CrowdloanMetadata,
        locale: Locale
    ) -> CrowdloansViewModel {
        let timeFormatter = TotalTimeFormatter()
        let quantityFormatter = NumberFormatter.quantity.localizableResource().value(for: locale)
        let tokenFormatter = amountFormatterFactory.createTokenFormatter(for: asset).value(for: locale)
        let displayFormatter = amountFormatterFactory.createDisplayFormatter(for: asset).value(for: locale)

        let formatters = Formatters(
            token: tokenFormatter,
            quantity: quantityFormatter,
            display: displayFormatter,
            time: timeFormatter
        )

        let (active, completed) = createSections(
            from: crowdloans,
            displayInfo: displayInfo,
            metadata: metadata,
            formatters: formatters,
            locale: locale
        )

        let activeSection: CrowdloansSectionViewModel<ActiveCrowdloanViewModel>? = {
            guard !active.isEmpty else {
                return nil
            }

            let countString = quantityFormatter.string(from: NSNumber(value: active.count)) ?? ""
            let title = R.string.localizable.crowdloanActiveSectionFormat(
                countString, preferredLanguages: locale.rLanguages
            )

            return CrowdloansSectionViewModel(title: title, crowdloans: active)
        }()

        let completedSection: CrowdloansSectionViewModel<CompletedCrowdloanViewModel>? = {
            guard !completed.isEmpty else {
                return nil
            }

            let countString = quantityFormatter.string(from: NSNumber(value: completed.count)) ?? ""
            let title = R.string.localizable.crowdloanCompletedSectionFormat(
                countString,
                preferredLanguages: locale.rLanguages
            )

            return CrowdloansSectionViewModel(title: title, crowdloans: completed)
        }()

        return CrowdloansViewModel(
            contributionsCount: nil,
            active: activeSection,
            completed: completedSection
        )
    }
}
