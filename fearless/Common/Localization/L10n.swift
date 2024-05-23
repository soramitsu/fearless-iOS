import Foundation

// swiftlint:disable all
public enum L10n {
    static var sharedLanguage = WalletLanguage.defaultLanguage

    public enum Account {
        /// Account details
        public static var detailsTitle: String { localize("account.details_title") }
    }

    public enum Amount {
        /// Transaction fee
        public static var defaultFee: String { localize("amount.defaultFee") }
        /// Transaction fee %@
        public static func fee(_ p1: String) -> String {
            localize("amount.fee", p1)
        }

        /// Set Amount
        public static var moduleTitle: String { localize("amount.module_title") }
        /// Amount to send
        public static var send: String { localize("amount.send") }
        /// Amount
        public static var title: String { localize("amount.title") }
        /// Total amount
        public static var total: String { localize("amount.total") }

        public enum Error {
            /// Sorry, we couldn't find asset information you want to send. Please, try again later.
            public static var asset: String { localize("amount.error.asset") }
            /// Sorry, balance checking request failed. Please, try again later.
            public static var balance: String { localize("amount.error.balance") }
            /// Sorry, you don't have enough funds to transfer specified amount.
            public static var noFunds: String { localize("amount.error.no_funds") }
            /// Sorry, minimal operation amount is %@.
            public static func operationMinLimit(_ p1: String) -> String {
                localize("amount.error.operation_min_limit", p1)
            }

            /// Sorry, we couldn't contact transfer provider. Please, try again later.
            public static var transfer: String { localize("amount.error.transfer") }
        }
    }

    public enum AssetSelection {
        /// No asset
        public static var noAsset: String { localize("asset_selection.no_asset") }
    }

    public enum Common {
        /// My account is:
        public static var accountShare: String { localize("common.account_share") }
        /// All
        public static var all: String { localize("common.all") }
        /// Cancel
        public static var cancel: String { localize("common.cancel") }
        /// Close
        public static var close: String { localize("common.close") }
        /// Copy
        public static var copy: String { localize("common.copy") }
        /// Description
        public static var description: String { localize("common.description") }
        /// Description (optional)
        public static var descriptionOptional: String { localize("common.description_optional") }
        /// Done
        public static var done: String { localize("common.done") }
        /// Error
        public static var error: String { localize("common.error") }
        /// %1$@ %2$@
        public static func fullName(_ p1: String, _ p2: String) -> String {
            localize("common.full_name", p1, p2)
        }

        /// Incoming
        public static var incoming: String { localize("common.incoming") }
        /// Next
        public static var next: String { localize("common.next") }
        /// Not now
        public static var notNow: String { localize("common.not_now") }
        /// OK
        public static var ok: String { localize("common.ok") }
        /// Open settings
        public static var openSettings: String { localize("common.open_settings") }
        /// Select an option
        public static var optionsTitle: String { localize("common.options_title") }
        /// Outgoing
        public static var outgoing: String { localize("common.outgoing") }
        /// Receive
        public static var receive: String { localize("common.receive") }
        /// Search
        public static var search: String { localize("common.search") }
        /// Send
        public static var send: String { localize("common.send") }
        /// Show less
        public static var showLess: String { localize("common.show_less") }
        /// Show more
        public static var showMore: String { localize("common.show_more") }
        /// Today
        public static var today: String { localize("common.today") }
        /// Yesterday
        public static var yesterday: String { localize("common.yesterday") }

        public enum Input {
            /// %@ lowercase hex symbols starting with 0x
            public static func validatorHint(_ p1: String) -> String {
                localize("common.input.validator_hint", p1)
            }

            /// Maximum %@ symbols
            public static func validatorMaxHint(_ p1: String) -> String {
                localize("common.input.validator_max_hint", p1)
            }
        }
    }

    public enum Confirmation {
        /// Please check and confirm details
        public static var hint: String { localize("confirmation.hint") }
        /// Confirmation
        public static var title: String { localize("confirmation.title") }

        public enum Title {
            /// Confirm Transaction
            public static var v1: String { localize("confirmation.title.v1") }
        }
    }

    public enum Contacts {
        /// Select recipient
        public static var moduleTitle: String { localize("contacts.module_title") }
        /// Scan QR code
        public static var scan: String { localize("contacts.scan") }
        /// Search results
        public static var searchResults: String { localize("contacts.search_results") }
        /// Contacts
        public static var title: String { localize("contacts.title") }
    }

    public enum Filter {
        /// Assets
        public static var assets: String { localize("filter.assets") }
        /// Date range
        public static var dateRange: String { localize("filter.dateRange") }
        /// From
        public static var from: String { localize("filter.from") }
        /// Reset
        public static var reset: String { localize("filter.reset") }
        /// Set filter
        public static var title: String { localize("filter.title") }
        /// To
        public static var to: String { localize("filter.to") }
        /// Type
        public static var type: String { localize("filter.type") }
    }

    public enum History {
        /// Recent events
        public static var title: String { localize("history.title") }
    }

    public enum InvoiceScan {
        /// Scan code from receiver
        public static var scan: String { localize("invoice_scan.scan") }
        /// Scan QR
        public static var title: String { localize("invoice_scan.title") }
        /// Upload from gallery
        public static var upload: String { localize("invoice_scan.upload") }

        public enum Error {
            /// Unfortunately, access to the camera is restricted.
            public static var cameraRestricted: String { localize("invoice_scan.error.camera_restricted") }
            /// Unfortunately, you denied access to camera previously. Would you like to allow access now?
            public static var cameraRestrictedPreviously: String { localize("invoice_scan.error.camera_restricted_previously") }
            /// Camera Access
            public static var cameraTitle: String { localize("invoice_scan.error.camera_title") }
            /// Can't extract receiver's data
            public static var extractFail: String { localize("invoice_scan.error.extract_fail") }
            /// Unfortunately, access to the photos is restricted.
            public static var galleryRestricted: String { localize("invoice_scan.error.gallery_restricted") }
            /// Unfortunately, you denied access to photos previously. Would you like to allow access now?
            public static var galleryRestrictedPreviously: String { localize("invoice_scan.error.gallery_restricted_previously") }
            /// Photos Access
            public static var galleryTitle: String { localize("invoice_scan.error.gallery_title") }
            /// Can't process selected image
            public static var invalidImage: String { localize("invoice_scan.error.invalid_image") }
            /// You can't send to yourself
            public static var match: String { localize("invoice_scan.error.match") }
            /// QR can't be decoded
            public static var noInfo: String { localize("invoice_scan.error.no_info") }
            /// Please, check internet connection
            public static var noInternet: String { localize("invoice_scan.error.no_internet") }
            /// Receiver couldn't be found
            public static var noReceiver: String { localize("invoice_scan.error.no_receiver") }
            /// Can't find a user from QR
            public static var userNotFound: String { localize("invoice_scan.error.user_not_found") }
        }
    }

    public enum Operation {
        /// Transaction fee
        public static var feeTitle: String { localize("operation.fee_title") }
    }

    public enum Receive {
        /// Can't generate QR code
        public static var errorQrGeneration: String { localize("receive.error_qr_generation") }
        /// Receive assets
        public static var title: String { localize("receive.title") }
    }

    public enum Status {
        /// Pending
        public static var pending: String { localize("status.pending") }
        /// Rejected
        public static var rejected: String { localize("status.rejected") }
        /// Success
        public static var success: String { localize("status.success") }
        /// Status
        public static var title: String { localize("status.title") }
    }

    public enum Transaction {
        /// Date and time
        public static var date: String { localize("transaction.date") }
        /// Transaction details
        public static var details: String { localize("transaction.details") }
        /// All done
        public static var done: String { localize("transaction.done") }
        /// Fee
        public static var fee: String { localize("transaction.fee") }
        /// Transaction ID
        public static var id: String { localize("transaction.id") }
        /// Funds are being sent
        public static var pendingDescription: String { localize("transaction.pending_description") }
        /// Reason
        public static var reason: String { localize("transaction.reason") }
        /// Recipient
        public static var recipient: String { localize("transaction.recipient") }
        /// Recipient ID
        public static var recipientId: String { localize("transaction.recipient_id") }
        /// Send again
        public static var sendAgain: String { localize("transaction.send_again") }
        /// Send back
        public static var sendBack: String { localize("transaction.send_back") }
        /// Sender
        public static var sender: String { localize("transaction.sender") }
        /// Sender ID
        public static var senderId: String { localize("transaction.sender_id") }
        /// Amount sent
        public static var sent: String { localize("transaction.sent") }
        /// Type
        public static var type: String { localize("transaction.type") }

        public enum Details {
            /// Transaction Details
            public static var v1: String { localize("transaction.details.v1") }
        }

        public enum Error {
            /// Transaction failed. Please, try again later.
            public static var fail: String { localize("transaction.error.fail") }
        }
    }

    public enum Withdraw {
        /// Withdraw
        public static var title: String { localize("withdraw.title") }
        /// Total amount %@%@
        public static func totalAmount(_ p1: String, _ p2: String) -> String {
            localize("withdraw.total_amount", p1, p2)
        }

        public enum Error {
            /// Sorry, balance checking request failed. Please, try again later.
            public static var balance: String { localize("withdraw.error.balance") }
            /// Sorry, we couldn't contact withdraw provider. Please, try again later.
            public static var connection: String { localize("withdraw.error.connection") }
            /// Withdraw failed. Please, try again later.
            public static var fail: String { localize("withdraw.error.fail") }
            /// Sorry, we couldn't find asset information you want to send. Please, try again later.
            public static var noAsset: String { localize("withdraw.error.no_asset") }
            /// Sorry, you don't have enough funds to transfer specified amount.
            public static var tooPoor: String { localize("withdraw.error.too_poor") }
        }
    }
}

private extension L10n {
    static func localize(_ key: String, _ args: CVarArg...) -> String {
        let format = getFormat(for: key, localization: sharedLanguage.rawValue)
        return String(format: format, arguments: args)
    }

    static func getFormat(for key: String, localization: String) -> String {
        let bundle = Bundle(for: BundleLoadHelper.self)

        guard
            let path = bundle.path(forResource: localization, ofType: "lproj"),
            let langBundle = Bundle(path: path) else {
            return ""
        }

        return NSLocalizedString(key, tableName: nil, bundle: langBundle, value: "", comment: "")
    }
}

private final class BundleLoadHelper {}
// swiftlint:enable all
