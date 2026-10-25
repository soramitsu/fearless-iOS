import GoogleAPIClientForREST_Drive
import GoogleAPIClientForRESTCore

public protocol GoogleServiceTicket {}

final class BaseGoogleServiceTicket: GoogleServiceTicket {
    private let ticket: GTLRServiceTicket

    init(ticket: GTLRServiceTicket) {
        self.ticket = ticket
    }
}
