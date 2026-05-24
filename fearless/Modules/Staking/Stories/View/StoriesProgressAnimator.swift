import UIKit
import FearlessUI

protocol StoriesProgressAnimatorProtocol {
    func redrawSegments(startingPosition: Int)
    func setCurrentSegment(newIndex: Int)
    func start()
    func resume()
    func pause()
    func stop()
}
