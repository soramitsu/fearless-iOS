import Foundation
import CommonWallet
import SoraFoundation

final class TransferConfigurator {
    lazy private var headerStyle: WalletContainingHeaderStyle = {
        let text = WalletTextStyle(font: UIFont.p1Paragraph,
                                   color: R.color.colorWhite()!)
        let contentInsets = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 16.0, right: 0.0)

        return WalletContainingHeaderStyle(titleStyle: text,
                                           horizontalSpacing: 6.0,
                                           contentInsets: contentInsets)
    }()

    lazy private var errorStyle: WalletContainingErrorStyle = {
        let error = WalletInlineErrorStyle(titleColor: UIColor(red: 0.942, green: 0, blue: 0.044, alpha: 1),
                                           titleFont: R.font.soraRc0040417Regular(size: 12)!,
                                           icon: R.image.iconWarning()!)
        let contentInsets = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 16.0, right: 0.0)
        return WalletContainingErrorStyle(inlineErrorStyle: error,
                                          horizontalSpacing: 6.0,
                                          contentInsets: contentInsets)
    }()

    lazy private var separatorStyle: WalletStrokeStyle = {
        WalletStrokeStyle(color: R.color.colorDarkGray()!, lineWidth: 1.0)
    }()

    lazy private var receiverStyle: WalletContainingReceiverStyle = {
        let textStyle = WalletTextStyle(font: UIFont.p1Paragraph,
                                        color: R.color.colorWhite()!)
        let contentInsets = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 15.0, right: 0.0)

        return WalletContainingReceiverStyle(containingHeaderStyle: headerStyle,
                                             textStyle: textStyle,
                                             horizontalSpacing: 8.0,
                                             contentInsets: contentInsets,
                                             separatorStyle: separatorStyle,
                                             containingErrorStyle: errorStyle)
    }()

    lazy private var feeStyle: WalletContainingFeeStyle = {
        let title = WalletTextStyle(font: UIFont.p1Paragraph,
                                    color: R.color.colorLightGray()!)
        let amount = WalletTextStyle(font: UIFont.p1Paragraph,
                                     color: R.color.colorWhite()!)
        let contentInsets = UIEdgeInsets(top: 14.0, left: 0.0, bottom: 14.0, right: 0.0)

        return WalletContainingFeeStyle(containingHeaderStyle: headerStyle,
                                        titleStyle: title,
                                        amountStyle: amount,
                                        activityTintColor: nil,
                                        displayStyle: .separatedDetails,
                                        horizontalSpacing: 10.0,
                                        contentInsets: contentInsets,
                                        separatorStyle: separatorStyle,
                                        containingErrorStyle: errorStyle)
    }()

    var commandFactory: WalletCommandFactoryProtocol? {
        get {
            viewModelFactory.commandFactory
        }

        set {
            viewModelFactory.commandFactory = newValue
        }
    }

    let localizationManager: LocalizationManagerProtocol

    let viewModelFactory: TransferViewModelFactory

    init(assets: [WalletAsset],
         amountFormatterFactory: NumberFormatterFactoryProtocol,
         localizationManager: LocalizationManagerProtocol) {
        viewModelFactory = TransferViewModelFactory(assets: assets,
                                                    amountFormatterFactory: amountFormatterFactory)
        self.localizationManager = localizationManager
    }

    func configure(builder: TransferModuleBuilderProtocol) {
        let title = LocalizableResource { locale in
            R.string.localizable.walletSendTitle(preferredLanguages: locale.rLanguages)
        }

        let definitionFactory = TransferDefinitionFactory(localizationManager: localizationManager)

        builder
            .with(localizableTitle: title)
            .with(containingHeaderStyle: headerStyle)
            .with(receiverStyle: receiverStyle)
            .with(feeStyle: feeStyle)
            .with(feeDisplayStyle: .separatedDetails)
            .with(receiverPosition: .form)
            .with(accessoryViewType: .onlyActionBar)
            .with(separatorsDistribution: TransferSeparatorDistribution())
            .with(headerFactory: TransferHeaderViewModelFactory())
            .with(transferViewModelFactory: viewModelFactory)
            .with(accessoryViewFactory: WalletSingleActionAccessoryFactory.self)
            .with(operationDefinitionFactory: definitionFactory)
            .with(resultValidator: TransferValidator())
    }
}
