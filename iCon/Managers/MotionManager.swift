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
    @Published var calibrationOffset: CMRotationRate = CMRotationRate(x: 0, y: 0, z: 0) // Gyro rotation rate offset

    private var updateInterval: TimeInterval

    init(updateInterval: TimeInterval = ControllerConstants.motionUpdateInterval) {
        self.updateInterval = updateInterval
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = self.updateInterval
            // For combined data (accel, gyro, attitude), ensure you're using startDeviceMotionUpdates.
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
        
        self.motionError = nil

        // Using deviceMotionUpdates provides combined data including attitude, rotationRate, and userAcceleration.
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
            guard let self = self else { return }

            if let error = error {
                let errorMsg = "Error receiving motion updates: \(error.localizedDescription)"
                self.logger.error("\(errorMsg)")
                if self.motionError == nil { self.motionError = errorMsg }
                self.isMotionActive = false
                return
            }

            if let motionData = motion {
                let rotationRate = motionData.rotationRate // CMRotationRate
                let userAcceleration = motionData.userAcceleration // CMAcceleration (gravity-compensated)
                let attitude = motionData.attitude // CMAttitude (roll, pitch, yaw)

                // Apply calibration offset ONLY to rotation rate
                let calibratedRotationX = rotationRate.x - self.calibrationOffset.x
                let calibratedRotationY = rotationRate.y - self.calibrationOffset.y
                let calibratedRotationZ = rotationRate.z - self.calibrationOffset.z

                let motionDataObject = GyroData(
                    accelerationX: userAcceleration.x,   // Typically in G's, convert to m/s^2 if needed (1G = 9.81 m/s^2)
                                                         // CoreMotion userAcceleration is already in G's. Multiply by 9.81 if m/s^2 is desired.
                                                         // For consistency, let's keep it as Gs and label units clearly.
                                                         // Or ensure host and client agree on units. For now, values as is.
                    accelerationY: userAcceleration.y,
                    accelerationZ: userAcceleration.z,
                    rotationX: calibratedRotationX,     // rad/s
                    rotationY: calibratedRotationY,
                    rotationZ: calibratedRotationZ,
                    roll: attitude.roll,                // radians
                    pitch: attitude.pitch,
                    yaw: attitude.yaw,
                    timestamp: Date()
                )
                
                DispatchQueue.main.async {
                    self.currentGyroData = motionDataObject
                }
            }
        }
        isMotionActive = true
        logger.info("Started device motion updates at \(1.0/self.updateInterval) Hz.")
    }

    func stopMotionUpdates() {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
            isMotionActive = false
            logger.info("Stopped device motion updates.")
        }
    }

    func calibrate() {
        // Calibration for gyroscope (rotation rate) zero offset.
        // User should keep the device still.
        guard motionManager.isDeviceMotionActive, let data = motionManager.deviceMotion?.rotationRate else {
            logger.warning("Cannot calibrate: motion updates not active or no rotation rate data available.")
            self.motionError = "Calibration failed: ensure motion is active and device is stable."
            return
        }
        calibrationOffset = data
        logger.info("Gyroscope rotation rate calibrated with offset: X: \(String(format: "%.2f", data.x)), Y: \(String(format: "%.2f", data.y)), Z: \(String(format: "%.2f", data.z))")
        self.motionError = nil // Clear error after successful calibration
    }
    
    func setUpdateInterval(_ newInterval: TimeInterval) {
        guard newInterval > 0 else { return }
        self.updateInterval = newInterval
        motionManager.deviceMotionUpdateInterval = self.updateInterval
        logger.info("Motion update interval set to \(1.0/newInterval) Hz.")
        if isMotionActive {
            stopMotionUpdates()
            startMotionUpdates()
        }
    }

    deinit {
        stopMotionUpdates()
    }
}
