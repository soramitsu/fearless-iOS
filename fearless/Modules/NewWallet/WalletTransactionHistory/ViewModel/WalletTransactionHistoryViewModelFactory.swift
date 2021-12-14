import CommonWallet
import RobinHood
import FearlessUtils

private typealias SearchableSection = (section: WalletTransactionHistorySection, index: Int)

protocol WalletTransactionHistoryViewModelFactoryProtocol {
    func merge(
        newItems: [AssetTransactionData],
        into existingViewModels: inout [WalletTransactionHistorySection],
        locale: Locale
    )
        -> [SectionedListDifference<WalletTransactionHistorySection, WalletTransactionHistoryCellViewModel>]
}

class WalletTransactionHistoryViewModelFactory: WalletTransactionHistoryViewModelFactoryProtocol {
    let balanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let includesFeeInAmount: Bool
    let transactionTypes: [WalletTransactionType]
    let asset: AssetModel
    let iconGenerator: IconGenerating

    init(
        balanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        includesFeeInAmount: Bool,
        transactionTypes: [WalletTransactionType],
        asset: AssetModel,
        iconGenerator: IconGenerating
    ) {
        self.balanceFormatterFactory = balanceFormatterFactory
        self.includesFeeInAmount = includesFeeInAmount
        self.transactionTypes = transactionTypes
        self.asset = asset
        self.iconGenerator = iconGenerator
    }

    func merge(
        newItems: [AssetTransactionData],
        into existingViewModels: inout [WalletTransactionHistorySection],
        locale: Locale
    )
        -> [SectionedListDifference<WalletTransactionHistorySection, WalletTransactionHistoryCellViewModel>] {
        var searchableSections = [String: SearchableSection]()
        for (index, section) in existingViewModels.enumerated() {
            searchableSections[section.title] = SearchableSection(section: section, index: index)
        }

        var changes = [SectionedListDifference<WalletTransactionHistorySection, WalletTransactionHistoryCellViewModel>]()

        newItems.forEach { event in
            let viewModel = createItemFromData(event, locale: locale)

            let eventDate = Date(timeIntervalSince1970: TimeInterval(event.timestamp))
            let sectionTitle = DateFormatter.txHistory.value(for: locale).string(from: eventDate)

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
    )
        -> WalletTransactionHistoryCellViewModel {
        let amountValue = data.amount.decimalValue

        var totalAmountValue = amountValue

        let optionalTransactionType = transactionTypes.first { $0.backendName == data.type }

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

        let amountFormatter = balanceFormatterFactory.createTokenFormatter(for: asset.displayInfo)

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

        let viewModel = WalletTransactionHistoryCellViewModel(
            address: address,
            icon: try? iconGenerator.generateFromAddress(address),
            transactionType: data.type,
            amountString: amountDisplayString,
            timeString: "",
            statusIcon: icon
        )
        return viewModel
    }
}
