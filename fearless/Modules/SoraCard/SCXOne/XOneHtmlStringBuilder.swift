import Foundation

final class XOneHtmlStringBuilder {
    static func build(with address: String, paymentId: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">

        <head>
          <meta name="description" content="" />
          <meta charset="utf-8">
          <title>x1ex</title>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="author" content="">
          <link rel="stylesheet" href="css/style.css">
        </head>

        <body>
        <div
            id="sprkwdgt-WYL6QBNC"
            data-from-currency="EUR"

            data-from-amount="\(KYCConstants.requiredAmountOfEuro)"
            data-hide-buy-more-button="true"
            data-hide-try-again-button="false"
            data-locale="en"
            data-payload="\(paymentId)"
            data-address="\(address)"
        ></div>
        <script async src="https://dev.x1ex.com/widgets/sdk.js"></script>

        </body>
        </html>
        """
    }
}
