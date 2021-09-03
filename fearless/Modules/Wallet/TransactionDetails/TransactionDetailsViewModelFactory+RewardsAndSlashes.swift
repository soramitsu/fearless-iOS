import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils
import IrohaCrypto

extension TransactionDetailsViewModelFactory {
    func createRewardAndSlashViewModels(
        isReward: Bool,
        data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) -> [WalletFormViewBindingProtocol]? {
        guard let chain = WalletAssetId(rawValue: data.assetId)?.chain else {
            return nil
        }

        var viewModels: [WalletFormViewBindingProtocol] = []

        populateEventId(
            in: &viewModels,
            data: data,
            chain: chain,
            commandFactory: commandFactory,
            locale: locale
        )

        populateValidatorId(
            in: &viewModels,
            data: data,
            chain: chain,
            commandFactory: commandFactory,
            locale: locale
        )

        populateStatus(into: &viewModels, data: data, locale: locale)
        populateTime(into: &viewModels, data: data, locale: locale)
        populateEra(into: &viewModels, data: data, locale: locale)

        let title = isReward ?
            R.string.localizable.stakingReward(preferredLanguages: locale.rLanguages) :
            R.string.localizable.stakingSlash(preferredLanguages: locale.rLanguages)
        populateAmount(into: &viewModels, title: title, data: data, locale: locale)

        return viewModels
    }

    func createRewardAndSlashAccessoryViewModel(
        data _: AssetTransactionData,
        commandFactory _: WalletCommandFactoryProtocol,
        locale _: Locale
    ) -> AccessoryViewModelProtocol? {
        nil
    }

    func populateEventId(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        data: AssetTransactionData,
        chain: Chain,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) {
        let title = R.string.localizable.stakingCommonEventId(preferredLanguages: locale.rLanguages)

        let actionIcon = R.image.iconMore()

        let command = WalletEventOpenCommand(
            eventId: data.transactionId,
            chain: chain,
            commandFactory: commandFactory,
            locale: locale
        )

        let viewModel = WalletCompoundDetailsViewModel(
            title: title,
            details: data.transactionId,
            mainIcon: nil,
            actionIcon: actionIcon,
            command: command,
            enabled: true
        )

        viewModelList.append(viewModel)
    }

    func populateValidatorId(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        data: AssetTransactionData,
        chain: Chain,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) {
        let title = R.string.localizable.stakingCommonValidator(preferredLanguages: locale.rLanguages)

        populatePeerViewModel(
            in: &viewModelList,
            title: title,
            address: data.peerId,
            chain: chain,
            commandFactory: commandFactory,
            locale: locale
        )
    }

    func populateEra(
        into viewModelList: inout [WalletFormViewBindingProtocol],
        data: AssetTransactionData,
        locale: Locale
    ) {
        guard
            let eraString = data.context?[TransactionContextKeys.era],
            let era = EraIndex(eraString),
            let displayEra = quantityFormatter.value(for: locale)
            .string(from: NSNumber(value: era)) else {
            return
        }

        let title = R.string.localizable.stakingCommonEra(preferredLanguages: locale.rLanguages)

        let details = "#\(displayEra)"

        let viewModel = WalletNewFormDetailsViewModel(
            title: title,
            titleIcon: nil,
            details: details,
            detailsIcon: nil
        )

        let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
        viewModelList.append(separator)
    }
}
