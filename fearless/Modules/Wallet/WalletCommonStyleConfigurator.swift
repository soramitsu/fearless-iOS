import Foundation
import CommonWallet

struct WalletCommonStyleConfigurator {
    let errorStyle = WalletInlineErrorStyle(titleColor: UIColor(red: 0.942, green: 0, blue: 0.044, alpha: 1),
                                            titleFont: R.font.soraRc0040417Regular(size: 12)!,
                                            icon: R.image.iconWarning()!)

    let navigationBarStyle: WalletNavigationBarStyleProtocol = {
        var navigationBarStyle = WalletNavigationBarStyle(barColor: R.color.colorAlmostBlack()!,
                                                          shadowColor: R.color.colorDarkGray()!,
                                                          itemTintColor: R.color.colorWhite()!,
                                                          titleColor: R.color.colorWhite()!,
                                                          titleFont: UIFont.h3Title)
        navigationBarStyle.titleFont = .h3Title
        navigationBarStyle.titleColor = R.color.colorWhite()!

        return navigationBarStyle
    }()
}

extension WalletCommonStyleConfigurator {
    func configure(builder: WalletStyleBuilderProtocol) {
        builder
        .with(background: R.color.colorAlmostBlack()!)
        .with(navigationBarStyle: navigationBarStyle)
        .with(header1: R.font.soraRc0040417Bold(size: 30.0)!)
        .with(header2: R.font.soraRc0040417SemiBold(size: 18.0)!)
        .with(header3: R.font.soraRc0040417Bold(size: 16.0)!)
        .with(header4: R.font.soraRc0040417Bold(size: 15.0)!)
        .with(bodyBold: R.font.soraRc0040417Bold(size: 14.0)!)
        .with(bodyRegular: R.font.soraRc0040417Regular(size: 14.0)!)
        .with(small: R.font.soraRc0040417Regular(size: 14.0)!)
        .with(keyboardIcon: R.image.iconKeyboardOff()!)
        .with(caretColor: R.color.colorWhite()!)
        .with(inlineErrorStyle: errorStyle)
    }
}
