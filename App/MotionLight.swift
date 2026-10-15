import CoreMotion
import Foundation
import Observation

/// A quiet, relative light direction. The owner starts it only while the lab is visible.
@Observable
@MainActor
final class MotionLight {
    private(set) var x: Double = 0
    private(set) var y: Double = 0
    private(set) var available = false

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var reference: CMAttitude?

    func start() {
        available = manager.isDeviceMotionAvailable
        guard available, !manager.isDeviceMotionActive else { return }
        reference = nil
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] sample, error in
            // Core Motion delivers this handler on OperationQueue.main.
            MainActor.assumeIsolated {
                guard let self else { return }
                guard error == nil, let sample else {
                    self.available = false
                    self.manager.stopDeviceMotionUpdates()
                    return
                }
                if self.reference == nil {
                    self.reference = sample.attitude.copy() as? CMAttitude
                }
                guard let reference = self.reference,
                      let relative = sample.attitude.copy() as? CMAttitude else { return }
                relative.multiply(byInverseOf: reference)
                let horizontal = max(-1.0, min(1.0, relative.roll / 0.65))
                let vertical = max(-1.0, min(1.0, relative.pitch / 0.65))
                self.x += (horizontal - self.x) * 0.18
                self.y += (vertical - self.y) * 0.18
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        reference = nil
        x = 0
        y = 0
    }

    func recenter() {
        reference = nil
        x = 0
        y = 0
    }
}
