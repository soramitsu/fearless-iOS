import Foundation
import CommonWallet

struct WalletCommonStyleConfigurator {
    let errorStyle = WalletInlineErrorStyle(titleColor: UIColor(red: 0.942, green: 0, blue: 0.044, alpha: 1),
                                            titleFont: R.font.soraRc0040417Regular(size: 12)!,
                                            icon: R.image.iconWarning()!)

    let navigationBarStyle: WalletNavigationBarStyleProtocol = {
        var navigationBarStyle = WalletNavigationBarStyle(barColor: R.color.colorBlack()!,
                                                          shadowColor: .clear,
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
        .with(background: R.color.colorBlack()!)
        .with(navigationBarStyle: navigationBarStyle)
        .with(header1: UIFont.h1Title)
        .with(header2: UIFont.h2Title)
        .with(header3: UIFont.h3Title)
        .with(header4: UIFont.h4Title)
        .with(bodyBold: UIFont.h5Title)
        .with(bodyRegular: UIFont.p1Paragraph)
        .with(small: UIFont.p2Paragraph)
        .with(keyboardIcon: R.image.iconKeyboardOff()!)
        .with(caretColor: R.color.colorWhite()!)
        .with(inlineErrorStyle: errorStyle)
    }
}
