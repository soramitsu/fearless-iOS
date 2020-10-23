import Foundation
import IrohaCrypto
import CommonWallet
import SoraFoundation

final class ContactsConfigurator {
    private var localSearchEngine: ContactsLocalSearchEngine

    private lazy var contactsViewStyle: ContactsViewStyleProtocol = {
        let searchTextStyle = WalletTextStyle(font: UIFont.p1Paragraph,
                                              color: R.color.colorWhite()!)
        let searchPlaceholderStyle = WalletTextStyle(font: UIFont.p1Paragraph,
                                                     color: R.color.colorLightGray()!)

        let searchStroke = WalletStrokeStyle(color: R.color.colorGray()!,
                                             lineWidth: 1.0)
        let searchFieldStyle = WalletRoundedViewStyle(fill: .clear,
                                                      cornerRadius: 8.0,
                                                      stroke: searchStroke)

        return ContactsViewStyle(backgroundColor: R.color.colorBlack()!,
                                 searchHeaderBackgroundColor: R.color.colorBlack()!,
                                 searchTextStyle: searchTextStyle,
                                 searchPlaceholderStyle: searchPlaceholderStyle,
                                 searchFieldStyle: searchFieldStyle,
                                 searchIndicatorStyle: R.color.colorGray()!,
                                 searchIcon: R.image.iconSearch(),
                                 searchSeparatorColor: .clear,
                                 tableSeparatorColor: R.color.colorDarkGray()!,
                                 actionsSeparator: WalletStrokeStyle(color: .clear, lineWidth: 0.0))
    }()

    private lazy var contactCellStyle: ContactCellStyleProtocol = {
        let iconStyle = WalletNameIconStyle(background: .white,
                                            title: WalletTextStyle(font: UIFont.p1Paragraph, color: .black),
                                            radius: 12.0)
        return ContactCellStyle(title: WalletTextStyle(font: UIFont.p1Paragraph, color: .white),
                                nameIcon: iconStyle,
                                accessoryIcon: R.image.iconSmallArrow(),
                                lineBreakMode: .byTruncatingMiddle,
                                selectionColor: R.color.colorDarkBlue()!.withAlphaComponent(0.3))
    }()

    private lazy var sectionHeaderStyle: ContactsSectionStyleProtocol = {
        let title = WalletTextStyle(font: UIFont.capsTitle,
                                    color: R.color.colorLightGray()!)
        return ContactsSectionStyle(title: title, uppercased: true)
    }()

    init(networkType: SNAddressType) {
        let viewModelFactory = ContactsViewModelFactory()
        localSearchEngine = ContactsLocalSearchEngine(networkType: networkType,
                                                      contactViewModelFactory: viewModelFactory)
    }

    func configure(builder: ContactsModuleBuilderProtocol) {
        let actionFactory = ContactsActionFactory()

        let searchPlaceholder = LocalizableResource { locale in
            R.string.localizable
                .walletContactsSearchPlaceholder(preferredLanguages: locale.rLanguages)
        }

        builder
            .with(localSearchEngine: localSearchEngine)
            .with(scanPosition: .barButton)
            .with(actionFactoryWrapper: actionFactory)
            .with(canFindItself: false)
            .with(supportsLiveSearch: true)
            .with(searchEmptyStateDataSource: WalletEmptyStateDataSource.search)
            .with(contactsEmptyStateDataSource: WalletEmptyStateDataSource.contacts)
            .with(viewStyle: contactsViewStyle)
            .with(contactCellStyle: contactCellStyle)
            .with(sectionHeaderStyle: sectionHeaderStyle)
            .with(searchPlaceholder: searchPlaceholder)
            .with(viewModelFactoryWrapper: localSearchEngine.contactViewModelFactory)
    }
}
