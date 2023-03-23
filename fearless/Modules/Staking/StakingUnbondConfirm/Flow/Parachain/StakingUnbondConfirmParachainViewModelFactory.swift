import Foundation
import FearlessUtils
import SoraFoundation

final class StakingUnbondConfirmParachainViewModelFactory: StakingUnbondConfirmViewModelFactoryProtocol {
    let asset: AssetModel
    let bondingDuration: UInt32?

    private lazy var formatterFactory = AssetBalanceFormatterFactory()
    private var iconGenerator: IconGenerating

    init(
        asset: AssetModel,
        bondingDuration: UInt32?,
        iconGenerator: IconGenerating
    ) {
        self.asset = asset
        self.bondingDuration = bondingDuration
        self.iconGenerator = iconGenerator
    }

    private func createHints(from _: Bool)
        -> LocalizableResource<[TitleIconViewModel]> {
        LocalizableResource { locale in
            var items = [TitleIconViewModel]()

            items.append(
                TitleIconViewModel(
                    title: R.string.localizable.stakingStakeLessHint(preferredLanguages: locale.rLanguages),
                    icon: R.image.iconInfoFilled()?.tinted(with: R.color.colorStrokeGray()!)
                )
            )

            return items
        }
    }

    func buildViewModel(viewModelState: StakingUnbondConfirmViewModelState) -> StakingUnbondConfirmViewModel? {
        guard let viewModelState = viewModelState as? StakingUnbondConfirmParachainViewModelState else {
            return nil
        }

        let formatter = formatterFactory.createTokenFormatter(for: asset.displayInfo)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).stringFromDecimal(viewModelState.inputAmount) ?? ""
        }

        let address = viewModelState.accountAddress ?? ""
        let accountIcon = try? iconGenerator.generateFromAddress(address)

        let collatorIcon = try? iconGenerator.generateFromAddress(viewModelState.candidate.address)

        let hints = createHints(from: false)

        return StakingUnbondConfirmViewModel(
            senderAddress: address,
            senderIcon: accountIcon,
            senderName: viewModelState.wallet.fetch(for: viewModelState.chainAsset.chain.accountRequest())?.name,
            collatorName: viewModelState.candidate.identity?.name,
            collatorIcon: collatorIcon,
            stakeAmountViewModel: createStakedAmountViewModel(viewModelState.inputAmount),
            amountString: amount,
            hints: hints
        )
    }

    func buildBondingDurationViewModel(
        viewModelState: StakingUnbondConfirmViewModelState
    ) -> LocalizableResource<TitleWithSubtitleViewModel>? {
        guard let viewModelState = viewModelState as? StakingUnbondConfirmParachainViewModelState else {
            return nil
        }

        let daysCount = bondingDuration.map { UInt32($0) / viewModelState.chainAsset.chain.erasPerDay }
        let viewModel: LocalizableResource<TitleWithSubtitleViewModel> = LocalizableResource { locale in
            guard let daysCount = daysCount else {
                return TitleWithSubtitleViewModel(title: "")
            }

            let title = R.string.localizable.stakingUnbondingPeriod_v190(preferredLanguages: locale.rLanguages)
            let subtitle = R.string.localizable.commonDaysFormat(
                format: Int(daysCount),
                preferredLanguages: locale.rLanguages
            )
            return TitleWithSubtitleViewModel(title: title, subtitle: subtitle)
        }
        return viewModel
    }

    func createStakedAmountViewModel(
        _ amount: Decimal
    ) -> LocalizableResource<StakeAmountViewModel>? {
        let localizableBalanceFormatter = formatterFactory.createTokenFormatter(for: asset.displayInfo)

        let iconViewModel = asset.displayInfo.icon.map { RemoteImageViewModel(url: $0) }

        return LocalizableResource { [weak self] locale in
            let amountString = localizableBalanceFormatter.value(for: locale).stringFromDecimal(amount) ?? ""
            let stakedString = R.string.localizable.poolStakingUnstakeAmountTitle(
                amountString,
                preferredLanguages: locale.rLanguages
            )
            let stakedAmountAttributedString = NSMutableAttributedString(string: stakedString)
            stakedAmountAttributedString.addAttribute(
                NSAttributedString.Key.foregroundColor,
                value: R.color.colorWhite() as Any,
                range: (stakedString as NSString).range(of: amountString)
            )

            return StakeAmountViewModel(
                amountTitle: stakedAmountAttributedString,
                iconViewModel: iconViewModel,
                color: self?.asset.color
            )
        }
    }
}
