import UIKit
import SoraUI

protocol StoriesProgressAnimatorProtocol {
    func redrawSegments(startingPosition: Int)
    func setCurrentIndex(newIndex: Int)
    func start()
    func resume()
    func pause()
    func stop()
}
