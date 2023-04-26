struct KYCReceivedFinalStatus: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processKYCReceivedFinalStatus()
    }
}
