struct KYCTokenChanged: EventProtocol {
    let token: SCToken

    func accept(visitor: EventVisitorProtocol) {
        visitor.processKYCTokenChanged(token: token)
    }
}
