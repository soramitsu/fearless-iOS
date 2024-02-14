import Foundation
import SSFModels
import SoraFoundation

protocol ClaimCrowdloanRewardViewModelFactoryProtocol {
    func buildBalanceViewModel(
        accountInfo: AccountInfo?,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>

    func buildVestingViewModel(
        balanceLocks: [LockProtocol]?,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>

    func createStakedAmountViewModel() -> LocalizableResource<StakeAmountViewModel>
    func buildHintViewModel() -> LocalizableResource<DetailsTriangularedAttributedViewModel?>
}

final class ClaimCrowdloanRewardViewModelFactory {
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let chainAsset: ChainAsset
    private lazy var formatterFactory = AssetBalanceFormatterFactory()

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        chainAsset: ChainAsset
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chainAsset = chainAsset
    }
}

extension ClaimCrowdloanRewardViewModelFactory: ClaimCrowdloanRewardViewModelFactoryProtocol {
    func buildBalanceViewModel(accountInfo: AccountInfo?, priceData: PriceData?) -> LocalizableResource<BalanceViewModelProtocol> {
        let transferableValue = accountInfo.map { accountInfo in
            let balance = Decimal.fromSubstrateAmount(accountInfo.data.sendAvailable, precision: Int16(chainAsset.asset.precision)) ?? .zero

            return balance
        } ?? .zero

        let transferableViewModel = balanceViewModelFactory.balanceFromPrice(
            transferableValue,
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        return transferableViewModel
    }

    func buildVestingViewModel(
        balanceLocks: [LockProtocol]?,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        let lockedRewardsValue = balanceLocks?.first { $0.lockType?.lowercased().contains("vest") == true }.map { lock in
            Decimal.fromSubstrateAmount(lock.amount, precision: Int16(chainAsset.asset.precision)) ?? .zero
        } ?? .zero
        let lockedRewardsViewModel = balanceViewModelFactory.balanceFromPrice(
            lockedRewardsValue,
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        return lockedRewardsViewModel
    }

    func createStakedAmountViewModel() -> LocalizableResource<StakeAmountViewModel> {
        let iconViewModel = chainAsset.asset.displayInfo.icon.map { RemoteImageViewModel(url: $0) }
        let symbol = chainAsset.asset.symbol.uppercased()
        return LocalizableResource { [weak self] _ in
            let stakedAmountAttributedString = NSMutableAttributedString(string: symbol)

            return StakeAmountViewModel(
                amountTitle: stakedAmountAttributedString,
                iconViewModel: iconViewModel,
                color: self?.chainAsset.asset.color
            )
        }
    }

    func buildHintViewModel() -> LocalizableResource<DetailsTriangularedAttributedViewModel?> {
        LocalizableResource { locale in
            let title = R.string.localizable.vestingClaimDisclaimerTitle(preferredLanguages: locale.rLanguages)
            let text = R.string.localizable.vestingClaimDisclaimerText(preferredLanguages: locale.rLanguages)

            let titleAttributedString = NSAttributedString(string: title, attributes: [.font: UIFont.h5Title])
            let textAttributedString = NSAttributedString(string: text)
            let resultString = NSMutableAttributedString()
            resultString.append(titleAttributedString)
            resultString.append(NSAttributedString(string: "\n"))
            resultString.append(textAttributedString)

            return DetailsTriangularedAttributedViewModel(
                icon: R.image.iconWarning()!,
                title: resultString
            )
        }
    }
}
