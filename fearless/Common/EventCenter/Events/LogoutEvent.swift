struct LogoutEvent: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processLogout()
    }
}
