import Foundation
import CommonWallet
import SoraFoundation

final class TransferConfigurator {
    lazy private var headerStyle: WalletContainingHeaderStyle = {
        let text = WalletTextStyle(font: UIFont.p1Paragraph,
                                   color: R.color.colorWhite()!)
        let contentInsets = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 0.0, right: 0.0)

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

    lazy private var assetStyle: WalletContainingAssetStyle = {
        let title = WalletTextStyle(font: UIFont.p1Paragraph,
                                    color: R.color.colorLightGray()!)
        let details = WalletTextStyle(font: UIFont.capsTitle,
                                      color: R.color.colorGreen()!)
        let contentInsets = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 16, right: 0.0)

        return WalletContainingAssetStyle(containingHeaderStyle: headerStyle,
                                          titleStyle: title,
                                          subtitleStyle: title,
                                          detailsStyle: details,
                                          switchIcon: R.image.iconDropDown(),
                                          contentInsets: contentInsets,
                                          titleHorizontalSpacing: 8.0,
                                          detailsHorizontalSpacing: 8.0,
                                          displayStyle: .separatedDetails,
                                          separatorStyle: separatorStyle,
                                          containingErrorStyle: errorStyle)
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

    lazy private var amountStyle: WalletContainingAmountStyle = {
        let textStyle = WalletTextStyle(font: UIFont.h3Title,
                                        color: R.color.colorWhite()!)
        let contentInsets = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 15, right: 0.0)

        return WalletContainingAmountStyle(containingHeaderStyle: headerStyle,
                                           assetStyle: textStyle,
                                           inputStyle: textStyle,
                                           keyboardIndicatorMode: .never,
                                           keyboardIcon: nil,
                                           caretColor: nil,
                                           horizontalSpacing: 5.0,
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

    let viewModelFactory: TransferViewModelFactoryOverriding

    init(assets: [WalletAsset], amountFormatterFactory: NumberFormatterFactoryProtocol) {
        viewModelFactory = TransferViewModelFactory(assets: assets,
                                                    amountFormatterFactory: amountFormatterFactory)
    }

    func configure(builder: TransferModuleBuilderProtocol) {
        let title = LocalizableResource { locale in
            R.string.localizable.walletSendTitle(preferredLanguages: locale.rLanguages)
        }

        builder
            .with(localizableTitle: title)
            .with(containingHeaderStyle: headerStyle)
            .with(selectedAssetStyle: assetStyle)
            .with(receiverStyle: receiverStyle)
            .with(amountStyle: amountStyle)
            .with(feeStyle: feeStyle)
            .with(feeDisplayStyle: .separatedDetails)
            .with(receiverPosition: .form)
            .with(accessoryViewType: .onlyActionBar)
            .with(separatorsDistribution: TransferSeparatorDistribution())
            .with(headerFactory: TransferHeaderViewModelFactory())
            .with(transferViewModelFactory: viewModelFactory)
    }
}
