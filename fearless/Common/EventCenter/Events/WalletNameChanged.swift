struct WalletNameChanged: EventProtocol {
    let wallet: MetaAccountModel

    func accept(visitor: EventVisitorProtocol) {
        visitor.processWalletNameChanged(event: self)
    }
}
