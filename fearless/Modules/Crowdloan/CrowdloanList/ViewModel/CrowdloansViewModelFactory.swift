import Foundation
import CommonWallet
import SoraFoundation
import IrohaCrypto
import FearlessUtils

protocol CrowdloansViewModelFactoryProtocol {
    func createViewModel(
        from crowdloans: [Crowdloan],
        displayInfo: CrowdloanDisplayInfoDict?,
        blockNumber: BlockNumber,
        locale: Locale
    ) -> CrowdloansViewModel
}

final class CrowdloansViewModelFactory {
    struct CommonContent {
        let title: String
        let details: String
        let progress: String
        let imageViewModel: WalletImageViewModelProtocol
    }

    struct Formatters {
        let token: TokenFormatter
        let quantity: NumberFormatter
        let display: LocalizableDecimalFormatting
    }

    let amountFormatterFactory: NumberFormatterFactoryProtocol
    let asset: WalletAsset
    let chain: Chain

    private lazy var addressFactory = SS58AddressFactory()
    private lazy var iconGenerator = PolkadotIconGenerator()

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
        let details: String? = {
            if let desc = displayInfo?.description {
                return desc
            } else {
                return depositorAddress
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

        let icon = try? iconGenerator.generateFromAddress(depositorAddress).imageWithFillColor(
            R.color.colorWhite()!,
            size: UIConstants.normalAddressIconSize,
            contentScale: UIScreen.main.scale
        )

        let imageViewModel = WalletStaticImageViewModel(staticImage: icon ?? UIImage())

        return CommonContent(
            title: title ?? "",
            details: details ?? "",
            progress: progress,
            imageViewModel: imageViewModel
        )
    }

    private func createActiveCrowdloanViewModel(
        from model: Crowdloan,
        displayInfo: CrowdloanDisplayInfo?,
        formatters: Formatters,
        locale: Locale
    ) -> ActiveCrowdloanViewModel? {
        guard let commonContent = createCommonContent(
            from: model,
            displayInfo: displayInfo,
            formatters: formatters,
            locale: locale
        ) else {
            return nil
        }

        return ActiveCrowdloanViewModel(
            title: commonContent.title,
            timeleft: "",
            description: commonContent.details,
            progress: commonContent.progress,
            iconViewModel: commonContent.imageViewModel
        )
    }
}

extension CrowdloansViewModelFactory: CrowdloansViewModelFactoryProtocol {
    func createViewModel(
        from crowdloans: [Crowdloan],
        displayInfo: CrowdloanDisplayInfoDict?,
        blockNumber _: BlockNumber,
        locale: Locale
    ) -> CrowdloansViewModel {
        let quantityFormatter = NumberFormatter.quantity.localizableResource().value(for: locale)
        let tokenFormatter = amountFormatterFactory.createTokenFormatter(for: asset).value(for: locale)
        let displayFormatter = amountFormatterFactory.createDisplayFormatter(for: asset).value(for: locale)

        let formatters = Formatters(
            token: tokenFormatter,
            quantity: quantityFormatter,
            display: displayFormatter
        )

        let activeCrowdloans: [CrowdloanSectionItem<ActiveCrowdloanViewModel>] =
            crowdloans.compactMap { crowdloan in
                guard let viewModel = createActiveCrowdloanViewModel(
                    from: crowdloan,
                    displayInfo: displayInfo?[crowdloan.paraId],
                    formatters: formatters,
                    locale: locale
                ) else {
                    return nil
                }

                return CrowdloanSectionItem(paraId: crowdloan.paraId, content: viewModel)
            }

        let activeSection: CrowdloansSectionViewModel<ActiveCrowdloanViewModel>? = {
            guard !activeCrowdloans.isEmpty else {
                return nil
            }

            let countString = quantityFormatter.string(from: NSNumber(value: activeCrowdloans.count)) ?? ""
            let title = R.string.localizable.crowdloanActiveSectionFormat(countString)

            return CrowdloansSectionViewModel(title: title, crowdloans: activeCrowdloans)
        }()

        return CrowdloansViewModel(
            contributionsCount: nil,
            active: activeSection,
            completed: nil
        )
    }
}
