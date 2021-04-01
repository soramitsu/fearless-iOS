import SoraUI

extension ProgressView {
    func stop() {
        guard let progressLayer = self.layer.sublayers?.last else { return }

        progressLayer.removeAllAnimations()
    }

    func pause() {
        guard let progressLayer = self.layer.sublayers?.last else { return }

        let pausedTime: CFTimeInterval = progressLayer.convertTime(CACurrentMediaTime(), from: nil)
        progressLayer.speed = 0.0
        progressLayer.timeOffset = pausedTime
    }

    func resume() {
        guard let progressLayer = self.layer.sublayers?.last else { return }

        let pausedTime = progressLayer.timeOffset
        progressLayer.speed = 1.0
        progressLayer.timeOffset = 0.0
        progressLayer.beginTime = 0.0
        let timeSincePause = progressLayer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
        progressLayer.beginTime = timeSincePause
    }
}
