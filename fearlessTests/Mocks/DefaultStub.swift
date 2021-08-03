import Foundation
import Cuckoo

extension MockEventCenterProtocol {
    func applyingDefaultStub() -> MockEventCenterProtocol {
        stub(self) { stub in
            stub.add(observer: any(), dispatchIn: any()).thenDoNothing()
            stub.notify(with: any()).thenDoNothing()
            stub.remove(observer: any()).thenDoNothing()
        }

        return self
    }
}
