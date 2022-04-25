import Foundation

protocol AssetPriceViewModelFactoryProtocol {
    var assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol { get }

    func buildPriceViewModel(
        for _: AssetModel,
        priceData: PriceData?,
        locale: Locale
    ) -> NSAttributedString?
}

extension AssetPriceViewModelFactoryProtocol {
    func buildPriceViewModel(
        for _: AssetModel,
        priceData: PriceData?,
        locale: Locale
    ) -> NSAttributedString? {
        let usdDisplayInfo = AssetBalanceDisplayInfo.usd()
        let usdTokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: usdDisplayInfo)
        let usdTokenFormatterValue = usdTokenFormatter.value(for: locale)

        guard let priceData = priceData,
              let priceDecimal = Decimal(string: priceData.price) else {
            return nil
        }

        let changeString: String = priceData.usdDayChange.map {
            let percentValue = $0 / 100
            return percentValue.percentString(locale: locale) ?? ""
        } ?? ""

        let priceString: String = usdTokenFormatterValue.stringFromDecimal(priceDecimal) ?? ""

        let priceWithChangeString = [priceString, changeString].joined(separator: " ")

        let priceWithChangeAttributed = NSMutableAttributedString(string: priceWithChangeString)

        let color = (priceData.usdDayChange ?? 0) > 0 ? R.color.colorGreen() : R.color.colorRed()

        if let color = color {
            priceWithChangeAttributed.addAttributes(
                [NSAttributedString.Key.foregroundColor: color],
                range: NSRange(
                    location: priceString.count + 1,
                    length: changeString.count
                )
            )
        }

        return priceWithChangeAttributed
    }
}
