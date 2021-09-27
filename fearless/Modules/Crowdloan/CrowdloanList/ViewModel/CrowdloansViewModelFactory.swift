import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils
import BigInt

protocol CrowdloansViewModelFactoryProtocol {
    func createChainViewModel(
        from chain: ChainModel,
        asset: AssetModel,
        balance: BigUInt?,
        locale: Locale
    ) -> CrowdloansChainViewModel

    func createViewModel(
        from crowdloans: [Crowdloan],
        viewInfo: CrowdloansViewInfo,
        chainAsset: ChainAssetDisplayInfo,
        locale: Locale
    ) -> CrowdloansViewModel
}

final class CrowdloansViewModelFactory {
    struct CommonContent {
        let title: String
        let details: CrowdloanDescViewModel
        let progress: String
        let imageViewModel: ImageViewModelProtocol
        let contribution: String?
    }

    struct Formatters {
        let token: TokenFormatter
        let quantity: NumberFormatter
        let display: LocalizableDecimalFormatting
        let time: TimeFormatterProtocol
    }

    let amountFormatterFactory: AssetBalanceFormatterFactoryProtocol

    private lazy var iconGenerator = PolkadotIconGenerator()

    private lazy var dateFormatter = {
        CompoundDateFormatterBuilder()
    }()

    init(
        amountFormatterFactory: AssetBalanceFormatterFactoryProtocol
    ) {
        self.amountFormatterFactory = amountFormatterFactory
    }

    private func createCommonContent(
        from model: Crowdloan,
        viewInfo: CrowdloansViewInfo,
        chainAsset: ChainAssetDisplayInfo,
        formatters: Formatters,
        locale: Locale
    ) -> CommonContent? {
        let displayInfo = viewInfo.displayInfo?[model.paraId]

        guard let depositorAddress = try? model.fundInfo.depositor.toAddress(using: chainAsset.chain) else {
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
                let raised = Decimal.fromSubstrateAmount(
                    model.fundInfo.raised,
                    precision: chainAsset.asset.assetPrecision
                ),
                let cap = Decimal.fromSubstrateAmount(
                    model.fundInfo.cap,
                    precision: chainAsset.asset.assetPrecision
                ),
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

        let contributionString: String? = {
            if
                let contributionInPlank = viewInfo.contributions[model.fundInfo.trieIndex]?.balance,
                let contributionDecimal = Decimal.fromSubstrateAmount(
                    contributionInPlank,
                    precision: chainAsset.asset.assetPrecision
                ) {
                return formatters.token.stringFromDecimal(contributionDecimal).map { value in
                    R.string.localizable.crowdloanContributionFormat(value, preferredLanguages: locale.rLanguages)
                }
            } else {
                return nil
            }
        }()

        return CommonContent(
            title: title ?? "",
            details: details,
            progress: progress,
            imageViewModel: iconViewModel,
            contribution: contributionString
        )
    }

    private func createActiveCrowdloanViewModel(
        from model: Crowdloan,
        viewInfo: CrowdloansViewInfo,
        chainAsset: ChainAssetDisplayInfo,
        formatters: Formatters,
        locale: Locale
    ) -> ActiveCrowdloanViewModel? {
        guard let commonContent = createCommonContent(
            from: model,
            viewInfo: viewInfo,
            chainAsset: chainAsset,
            formatters: formatters,
            locale: locale
        ) else {
            return nil
        }

        let timeLeft: String = {
            let remainedTime = model.remainedTime(
                at: viewInfo.metadata.blockNumber,
                blockDuration: viewInfo.metadata.blockDuration
            )

            if remainedTime.daysFromSeconds > 0 {
                return R.string.localizable.commonDaysFormat(
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
            iconViewModel: commonContent.imageViewModel,
            contribution: commonContent.contribution
        )
    }

    private func createCompletedCrowdloanViewModel(
        from model: Crowdloan,
        viewInfo: CrowdloansViewInfo,
        chainAsset: ChainAssetDisplayInfo,
        formatters: Formatters,
        locale: Locale
    ) -> CompletedCrowdloanViewModel? {
        guard let commonContent = createCommonContent(
            from: model,
            viewInfo: viewInfo,
            chainAsset: chainAsset,
            formatters: formatters,
            locale: locale
        ) else {
            return nil
        }

        return CompletedCrowdloanViewModel(
            title: commonContent.title,
            description: commonContent.details,
            progress: commonContent.progress,
            iconViewModel: commonContent.imageViewModel,
            contribution: commonContent.contribution
        )
    }

    func createSections(
        from crowdloans: [Crowdloan],
        viewInfo: CrowdloansViewInfo,
        chainAsset: ChainAssetDisplayInfo,
        formatters: Formatters,
        locale: Locale
    ) -> ([CrowdloanActiveSection], [CrowdloanCompletedSection]) {
        let initial = (
            [CrowdloanActiveSection](),
            [CrowdloanCompletedSection]()
        )

        return crowdloans.sorted { crowdloan1, crowdloan2 in
            if crowdloan1.fundInfo.raised != crowdloan2.fundInfo.raised {
                return crowdloan1.fundInfo.raised > crowdloan2.fundInfo.raised
            } else {
                return crowdloan1.fundInfo.end < crowdloan2.fundInfo.end
            }
        }.reduce(into: initial) { result, crowdloan in
            let hasWonAuction = viewInfo.leaseInfo[crowdloan.paraId]?.leasedAmount != nil
            if hasWonAuction || crowdloan.isCompleted(for: viewInfo.metadata) {
                if let viewModel = createCompletedCrowdloanViewModel(
                    from: crowdloan,
                    viewInfo: viewInfo,
                    chainAsset: chainAsset,
                    formatters: formatters,
                    locale: locale
                ) {
                    let sectionItem = CrowdloanSectionItem(paraId: crowdloan.paraId, content: viewModel)
                    result.1.append(sectionItem)
                }
            } else {
                if let viewModel = createActiveCrowdloanViewModel(
                    from: crowdloan,
                    viewInfo: viewInfo,
                    chainAsset: chainAsset,
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
    func createChainViewModel(
        from chain: ChainModel,
        asset: AssetModel,
        balance: BigUInt?,
        locale: Locale
    ) -> CrowdloansChainViewModel {
        let displayInfo = asset.displayInfo

        let amountFormatter = amountFormatterFactory.createTokenFormatter(
            for: asset.displayInfo
        ).value(for: locale)

        let amount: String

        if
            let balance = balance,
            let decimalAmount = Decimal.fromSubstrateAmount(
                balance,
                precision: displayInfo.assetPrecision
            ) {
            amount = amountFormatter.stringFromDecimal(decimalAmount) ?? ""
        } else {
            amount = ""
        }

        let imageViewModel = RemoteImageViewModel(url: chain.icon)

        let description = R.string.localizable.crowdloanListSectionFormat(
            displayInfo.symbol,
            preferredLanguages: locale.rLanguages
        )

        return CrowdloansChainViewModel(
            networkName: chain.name,
            balance: amount,
            imageViewModel: imageViewModel,
            description: description
        )
    }

    func createViewModel(
        from crowdloans: [Crowdloan],
        viewInfo: CrowdloansViewInfo,
        chainAsset: ChainAssetDisplayInfo,
        locale: Locale
    ) -> CrowdloansViewModel {
        let timeFormatter = TotalTimeFormatter()
        let quantityFormatter = NumberFormatter.quantity.localizableResource().value(for: locale)
        let tokenFormatter = amountFormatterFactory.createTokenFormatter(
            for: chainAsset.asset
        ).value(for: locale)

        let displayFormatter = amountFormatterFactory.createDisplayFormatter(
            for: chainAsset.asset
        ).value(for: locale)

        let formatters = Formatters(
            token: tokenFormatter,
            quantity: quantityFormatter,
            display: displayFormatter,
            time: timeFormatter
        )

        let (active, completed) = createSections(
            from: crowdloans,
            viewInfo: viewInfo,
            chainAsset: chainAsset,
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
            tokenSymbol: chainAsset.asset.symbol,
            contributionsCount: nil,
            active: activeSection,
            completed: completedSection
        )
    }
}
