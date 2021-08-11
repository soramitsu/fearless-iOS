import SoraFoundation
import FearlessUtils
import BigInt

final class AnalyticsValidatorsViewModelFactory: AnalyticsValidatorsViewModelFactoryProtocol {
    private lazy var iconGenerator = PolkadotIconGenerator()

    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let selectedAddress: AccountAddress
    private let chain: Chain

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        selectedAddress: AccountAddress,
        chain: Chain
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.selectedAddress = selectedAddress
        self.chain = chain
    }

    func createViewModel(
        eraValidatorInfos: [SQEraValidatorInfo],
        identitiesByAddress: [AccountAddress: AccountIdentity]?,
        page: AnalyticsValidatorsPage
    ) -> LocalizableResource<AnalyticsValidatorsViewModel> {
        LocalizableResource { locale in
            let totalEras = self.totalErasCount(eraValidatorInfos: eraValidatorInfos)

            let distinctValidators = Set<String>(eraValidatorInfos.map(\.address))

            let validators: [AnalyticsValidatorItemViewModel] = distinctValidators.map { address in

                let icon = try? self.iconGenerator.generateFromAddress(address)
                let validatorName = (identitiesByAddress?[address]?.displayName) ?? address
                let (progress, progressText): (Double, String) = {
                    switch page {
                    case .activity:
                        let infos = eraValidatorInfos.filter { $0.address == address }
                        let distinctEras = Set<EraIndex>(infos.map(\.era))
                        let distinctErasCount = distinctEras.count

                        let percents = Int(Double(distinctErasCount) / Double(totalEras) * 100.0)
                        return (Double(percents), "\(percents)% (\(distinctErasCount) eras)")
                    case .rewards:
                        let infos = eraValidatorInfos.filter { $0.address == address }
                        let aaa = infos.flatMap(\.others).filter { $0.who == self.selectedAddress }
                        let totalAmount = aaa.reduce(Decimal(0)) { amount, info in
                            let amountBigInt = BigUInt(stringLiteral: info.value)
                            let decimal = Decimal.fromSubstrateAmount(amountBigInt, precision: self.chain.addressType.precision)
                            return amount + (decimal ?? 0.0)
                        }
                        let totalAmounText = self.balanceViewModelFactory
                            .amountFromValue(totalAmount).value(for: locale)
                        let double = NSDecimalNumber(decimal: totalAmount).doubleValue
                        return (double, totalAmounText)
                    }
                }()

                return .init(
                    icon: icon,
                    validatorName: validatorName,
                    progress: progress,
                    progressText: progressText,
                    validatorAddress: address
                )
            }
            .sorted(by: { $0.progress > $1.progress })

            let chartData = ChartData(amounts: [1, 2], xAxisValues: ["a", "b"])
            let listTitle = self.determineListTitle(page: page, locale: locale)
            return AnalyticsValidatorsViewModel(
                chartData: chartData,
                listTitle: listTitle,
                validators: validators,
                selectedPage: page
            )
        }
    }

    private func determineListTitle(page: AnalyticsValidatorsPage, locale _: Locale) -> String {
        switch page {
        case .activity:
            return "stake allocation".uppercased()
        case .rewards:
            return "Rewards".uppercased()
        }
    }

    func totalErasCount(eraValidatorInfos: [SQEraValidatorInfo]) -> Int {
        let distinctEras = Set<EraIndex>(eraValidatorInfos.map(\.era))
        return distinctEras.count
    }

    func progressDescription(
        page: AnalyticsValidatorsPage,
        validatorInfo: SQEraValidatorInfo,
        totalErasCount: Int,
        locale: Locale
    ) -> String {
        switch page {
        case .activity:
            return progressDescriptionStake(
                validatorInfo: validatorInfo,
                totalErasCount: totalErasCount,
                locale: locale
            )
        case .rewards:
            return "0 KSM"
        }
    }

    func progressDescriptionStake(
        validatorInfo _: SQEraValidatorInfo,
        totalErasCount: Int,
        locale _: Locale
    ) -> String {
        "(\(totalErasCount) eras)"
    }
}
