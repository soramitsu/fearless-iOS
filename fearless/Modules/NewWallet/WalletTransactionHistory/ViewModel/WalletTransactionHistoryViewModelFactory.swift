import CommonWallet
import RobinHood
import FearlessUtils
import UIKit

private typealias SearchableSection = (section: WalletTransactionHistorySection, index: Int)

let extrinsicFeeCallNames: [String] = ["transfer", "contribute"]

protocol WalletTransactionHistoryViewModelFactoryProtocol {
    func merge(
        newItems: [AssetTransactionData],
        into existingViewModels: inout [WalletTransactionHistorySection],
        locale: Locale
    ) throws -> [SectionedListDifference<WalletTransactionHistorySection, WalletTransactionHistoryCellViewModel>]
}

class WalletTransactionHistoryViewModelFactory: WalletTransactionHistoryViewModelFactoryProtocol {
    let balanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let includesFeeInAmount: Bool
    let transactionTypes: [WalletTransactionType]
    let chainAsset: ChainAsset
    let iconGenerator: IconGenerating

    init(
        balanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        includesFeeInAmount: Bool,
        transactionTypes: [WalletTransactionType],
        chainAsset: ChainAsset,
        iconGenerator: IconGenerating
    ) {
        self.balanceFormatterFactory = balanceFormatterFactory
        self.includesFeeInAmount = includesFeeInAmount
        self.transactionTypes = transactionTypes
        self.chainAsset = chainAsset
        self.iconGenerator = iconGenerator
    }

    func merge(
        newItems: [AssetTransactionData],
        into existingViewModels: inout [WalletTransactionHistorySection],
        locale: Locale
    ) throws -> [SectionedListDifference<WalletTransactionHistorySection, WalletTransactionHistoryCellViewModel>] {
        var searchableSections = [String: SearchableSection]()
        for (index, section) in existingViewModels.enumerated() {
            searchableSections[section.title] = SearchableSection(section: section, index: index)
        }

        var changes = [SectionedListDifference<WalletTransactionHistorySection, WalletTransactionHistoryCellViewModel>]()

        try newItems.forEach { event in
            let viewModel = try createItemFromData(event, locale: locale)

            let eventDate = Date(timeIntervalSince1970: TimeInterval(event.timestamp))
            let sectionTitle = DateFormatter.sectionedDate.value(for: locale).string(from: eventDate)

            if var searchableSection = searchableSections[sectionTitle] {
                let itemChange = ListDifference.insert(index: searchableSection.section.items.count, new: viewModel)
                let sectionChange = SectionedListDifference<WalletTransactionHistorySection, WalletTransactionHistoryCellViewModel>.update(
                    index: searchableSection.index,
                    itemChange: itemChange,
                    section: searchableSection.section
                )
                changes.append(sectionChange)

                searchableSection.section.items.append(viewModel)
            } else {
                let newSection = WalletTransactionHistorySection(
                    title: sectionTitle,
                    items: [viewModel]
                )

                let change: SectionedListDifference<WalletTransactionHistorySection, WalletTransactionHistoryCellViewModel>
                    = .insert(index: searchableSections.count, newSection: newSection)

                changes.append(change)

                let searchableSection = SearchableSection(section: newSection, index: existingViewModels.count)
                searchableSections[newSection.title] = searchableSection

                existingViewModels.append(newSection)
            }
        }

        return changes
    }

    func createItemFromData(
        _ data: AssetTransactionData,
        locale: Locale
    ) throws -> WalletTransactionHistoryCellViewModel {
        guard let transactionType = TransactionType(rawValue: data.type) else {
            throw TransactionHistoryViewModelFactoryError.unsupportedType
        }

        switch transactionType {
        case .incoming, .outgoing:
            return try createTransferItemFromData(
                data,
                locale: locale,
                txType: transactionType
            )
        case .reward, .slash:
            return try createRewardOrSlashItemFromData(
                data,
                locale: locale,
                txType: transactionType
            )
        case .extrinsic:
            return try createExtrinsicItemFromData(
                data,
                locale: locale,
                txType: transactionType
            )
        }
    }

    private func createTransferItemFromData(
        _ data: AssetTransactionData,
        locale: Locale,
        txType _: TransactionType
    ) throws -> WalletTransactionHistoryCellViewModel {
        let amountValue = data.amount.decimalValue

        var totalAmountValue = amountValue

        let optionalTransactionType = transactionTypes.first { $0.backendName.lowercased() == data.type.lowercased() }

        if includesFeeInAmount,
           let transactionType = optionalTransactionType,
           !transactionType.isIncome {
            let totalFee = data.fees.reduce(Decimal(0)) { result, item in
                if item.assetId == data.assetId {
                    return result + item.amount.decimalValue
                } else {
                    return result
                }
            }

            totalAmountValue += totalFee
        }

        let amountFormatter = balanceFormatterFactory.createTokenFormatter(for: chainAsset.asset.displayInfo)

        let amountDisplayString = amountFormatter.value(for: locale).stringFromDecimal(totalAmountValue) ?? ""

        let address: String

        if data.peerFirstName != nil || data.peerLastName != nil {
            let firstName = data.peerFirstName ?? ""
            let lastName = data.peerLastName ?? ""

            address = L10n.Common.fullName(firstName, lastName)
        } else {
            address = data.peerName ?? ""
        }

        let incoming: Bool
        let icon: UIImage? = data.status == .rejected ? R.image.iconTxFailed() : nil

        if let transactionType = optionalTransactionType {
            incoming = transactionType.isIncome
        } else {
            incoming = false
        }

        let signString = incoming ? "+" : "-"

        let date = Date(timeIntervalSince1970: TimeInterval(data.timestamp))
        let dateString = DateFormatter.txHistory.value(for: locale).string(from: date)

        let viewModel = WalletTransactionHistoryCellViewModel(
            transaction: data,
            address: address,
            icon: try? iconGenerator.generateFromAddress(address).imageWithFillColor(R.color.colorWhite()!, size: CGSize(width: 50, height: 50), contentScale: UIScreen.main.scale),
            transactionType: data.type,
            amountString: signString.appending(amountDisplayString),
            timeString: dateString,
            statusIcon: icon,
            status: data.status,
            incoming: incoming,
            imageViewModel: nil
        )
        return viewModel
    }

    private func createRewardOrSlashItemFromData(
        _ data: AssetTransactionData,
        locale: Locale,
        txType: TransactionType
    ) throws -> WalletTransactionHistoryCellViewModel {
        let amountValue = data.amount.decimalValue

        var totalAmountValue = amountValue

        let optionalTransactionType = transactionTypes.first { $0.backendName.lowercased() == data.type.lowercased() }

        if includesFeeInAmount,
           let transactionType = optionalTransactionType,
           !transactionType.isIncome {
            let totalFee = data.fees.reduce(Decimal(0)) { result, item in
                if item.assetId == data.assetId {
                    return result + item.amount.decimalValue
                } else {
                    return result
                }
            }

            totalAmountValue += totalFee
        }

        let amountFormatter = balanceFormatterFactory.createTokenFormatter(for: chainAsset.asset.displayInfo)

        let amountDisplayString = amountFormatter.value(for: locale).stringFromDecimal(totalAmountValue) ?? ""

        let address: String = txType == .reward ?
            R.string.localizable.stakingReward(preferredLanguages: locale.rLanguages) :
            R.string.localizable.stakingSlash(preferredLanguages: locale.rLanguages)

        let icon: UIImage? = R.image.iconRewardAndSlashes()

        let date = Date(timeIntervalSince1970: TimeInterval(data.timestamp))
        let dateString = DateFormatter.txHistory.value(for: locale).string(from: date)

        let signString = "+"

        let viewModel = WalletTransactionHistoryCellViewModel(
            transaction: data,
            address: address,
            icon: icon,
            transactionType: R.string.localizable.stakingTitle(preferredLanguages: locale.rLanguages),
            amountString: signString.appending(amountDisplayString),
            timeString: dateString,
            statusIcon: nil,
            status: data.status,
            incoming: true,
            imageViewModel: nil
        )
        return viewModel
    }

    private func createExtrinsicItemFromData(
        _ data: AssetTransactionData,
        locale: Locale,
        txType _: TransactionType
    ) throws -> WalletTransactionHistoryCellViewModel {
        let amountValue = data.amount.decimalValue

        var totalAmountValue = amountValue

        let optionalTransactionType = transactionTypes.first { $0.backendName.lowercased() == data.type.lowercased() }

        if includesFeeInAmount,
           let transactionType = optionalTransactionType,
           !transactionType.isIncome {
            let totalFee = data.fees.reduce(Decimal(0)) { result, item in
                if item.assetId == data.assetId {
                    return result + item.amount.decimalValue
                } else {
                    return result
                }
            }

            totalAmountValue += totalFee
        }

        let amountFormatter = balanceFormatterFactory.createTokenFormatter(for: chainAsset.asset.displayInfo)

        let amountDisplayString = amountFormatter.value(for: locale).stringFromDecimal(totalAmountValue) ?? ""

        let address: String

        if data.peerFirstName != nil || data.peerLastName != nil {
            let firstName = data.peerFirstName ?? ""
            let lastName = data.peerLastName ?? ""

            address = L10n.Common.fullName(firstName, lastName)
        } else {
            address = data.peerName ?? ""
        }

        let incoming: Bool
        let icon: UIImage?

        if let transactionType = optionalTransactionType {
            incoming = transactionType.isIncome
            icon = transactionType.typeIcon
        } else {
            incoming = false
            icon = nil
        }

        let date = Date(timeIntervalSince1970: TimeInterval(data.timestamp))
        let dateString = DateFormatter.txHistory.value(for: locale).string(from: date)

        let signString = incoming ? "+" : "-"

        let moduleName = data.peerFirstName?.capitalized ?? ""
        var callName = data.peerLastName?.capitalized ?? ""

        if extrinsicFeeCallNames.contains(callName.lowercased()) {
            callName.append(" fee")
        }

        var imageViewModel: RemoteImageViewModel?
        if let assetIconURL = chainAsset.chain.icon {
            imageViewModel = RemoteImageViewModel(url: assetIconURL)
        }

        let viewModel = WalletTransactionHistoryCellViewModel(
            transaction: data,
            address: moduleName,
            icon: nil,
            transactionType: callName,
            amountString: signString.appending(amountDisplayString),
            timeString: dateString,
            statusIcon: icon,
            status: data.status,
            incoming: incoming,
            imageViewModel: imageViewModel
        )

        return viewModel
    }
}
