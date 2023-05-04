import Foundation

class DisconnectOperation: Operation {
    let connection: ChainConnection

    init(connection: ChainConnection) {
        self.connection = connection
    }

    override func main() {
        connection.disconnectIfNeeded()
    }
}
