import Foundation

class ConnectOperation: Operation {
    let connection: ChainConnection

    init(connection: ChainConnection) {
        self.connection = connection
    }

    override func main() {
        connection.connectIfNeeded()
    }
}
