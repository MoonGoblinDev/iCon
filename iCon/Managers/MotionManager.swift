// TennisController/Main App/Managers/MotionManager.swift
import Foundation
import CoreMotion
import Combine
import os.log

class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.example.TennisController", category: "MotionManager")

    @Published var currentGyroData: GyroData?
    @Published var isMotionActive: Bool = false
    @Published var motionError: String?
    @Published var calibrationOffset: CMRotationRate = CMRotationRate(x: 0, y: 0, z: 0)

    private var updateInterval: TimeInterval

    init(updateInterval: TimeInterval = ControllerConstants.motionUpdateInterval) {
        self.updateInterval = updateInterval
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = self.updateInterval
        } else {
            let errorMsg = "Device motion is not available on this device."
            logger.error("\(errorMsg)")
            self.motionError = errorMsg
        }
    }

    func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            logger.warning("Attempted to start motion updates, but device motion is not available.")
            self.motionError = "Device motion not available."
            return
        }

        guard !motionManager.isDeviceMotionActive else {
            logger.info("Motion updates are already active.")
            return
        }
        
        // Reset error on start
        self.motionError = nil

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
            guard let self = self else { return }

            if let error = error {
                let errorMsg = "Error receiving motion updates: \(error.localizedDescription)"
                self.logger.error("\(errorMsg)")
                // Keep last known error, but don't override if it's already set by availability check
                if self.motionError == nil { self.motionError = errorMsg }
                self.isMotionActive = false // Ensure state reflects reality
                return
            }

            if let motionData = motion {
                let rotationRate = motionData.rotationRate
                let calibratedX = rotationRate.x - self.calibrationOffset.x
                let calibratedY = rotationRate.y - self.calibrationOffset.y
                let calibratedZ = rotationRate.z - self.calibrationOffset.z

                let gyroData = GyroData(x: calibratedX, y: calibratedY, z: calibratedZ, timestamp: Date())
                
                DispatchQueue.main.async {
                    self.currentGyroData = gyroData
                }
            }
        }
        isMotionActive = true
        logger.info("Started motion updates at \(1.0/self.updateInterval) Hz.")
    }

    func stopMotionUpdates() {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
            isMotionActive = false
            logger.info("Stopped motion updates.")
        }
    }

    func calibrate() {
        // Attempt to get a stable reading. Could ask user to keep device still.
        // For simplicity, using instantaneous data.
        guard motionManager.isDeviceMotionActive, let data = motionManager.deviceMotion?.rotationRate else {
            logger.warning("Cannot calibrate: motion updates not active or no data available.")
            // Potentially provide feedback to the user here
            self.motionError = "Calibration failed: ensure motion is active and stable."
            return
        }
        calibrationOffset = data
        logger.info("Gyroscope calibrated with offset: X: \(String(format: "%.2f", data.x)), Y: \(String(format: "%.2f", data.y)), Z: \(String(format: "%.2f", data.z))")
        self.motionError = nil // Clear error after successful calibration
    }
    
    func setUpdateInterval(_ newInterval: TimeInterval) {
        guard newInterval > 0 else { return }
        self.updateInterval = newInterval
        motionManager.deviceMotionUpdateInterval = self.updateInterval
        logger.info("Motion update interval set to \(1.0/newInterval) Hz.")
        // If active, might need to restart to apply immediately for some CM versions or scenarios
        if isMotionActive {
            stopMotionUpdates()
            startMotionUpdates()
        }
    }

    deinit {
        stopMotionUpdates()
    }
}
