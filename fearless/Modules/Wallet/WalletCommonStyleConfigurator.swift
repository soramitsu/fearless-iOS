import Foundation
import CommonWallet

struct WalletCommonStyleConfigurator {
    let errorStyle = WalletInlineErrorStyle(titleColor: UIColor(red: 0.942, green: 0, blue: 0.044, alpha: 1),
                                            titleFont: R.font.soraRc0040417Regular(size: 12)!,
                                            icon: R.image.iconWarning()!)

    let navigationBarStyle: WalletNavigationBarStyleProtocol = {
        var navigationBarStyle = WalletNavigationBarStyle(barColor: UIColor.navigationBarColor,
                                                          shadowColor: UIColor.darkNavigationShadowColor,
                                                          itemTintColor: UIColor.navigationBarBackTintColor,
                                                          titleColor: UIColor.navigationBarTitleColor,
                                                          titleFont: UIFont.navigationTitleFont)
        navigationBarStyle.titleFont = .navigationTitleFont
        navigationBarStyle.titleColor = .navigationBarTitleColor

        return navigationBarStyle
    }()
}

extension WalletCommonStyleConfigurator {
    func configure(builder: WalletStyleBuilderProtocol) {
        builder
        .with(background: .background)
        .with(navigationBarStyle: navigationBarStyle)
        .with(header1: R.font.soraRc0040417Bold(size: 30.0)!)
        .with(header2: R.font.soraRc0040417SemiBold(size: 18.0)!)
        .with(header3: R.font.soraRc0040417Bold(size: 16.0)!)
        .with(header4: R.font.soraRc0040417Bold(size: 15.0)!)
        .with(bodyBold: R.font.soraRc0040417Bold(size: 14.0)!)
        .with(bodyRegular: R.font.soraRc0040417Regular(size: 14.0)!)
        .with(small: R.font.soraRc0040417Regular(size: 14.0)!)
        .with(keyboardIcon: R.image.iconKeyboardOff()!)
        .with(caretColor: UIColor.iconTintColor)
        .with(inlineErrorStyle: errorStyle)
    }
}
