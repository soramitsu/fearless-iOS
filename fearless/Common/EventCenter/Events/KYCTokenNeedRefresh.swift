struct KYCTokenNeedRefresh: EventProtocol {
    let token: SCToken

    func accept(visitor: EventVisitorProtocol) {
        visitor.processKYCTokenNeedRefresh(token: token)
    }
}
