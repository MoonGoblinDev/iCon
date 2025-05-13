// Shared: Challenge2/Models/GyroData.swift
// Shared: iCon/Models/GyroData.swift
import Foundation

struct GyroData: Codable, Identifiable, Equatable {
    var id = UUID()
    var accelerationX: Double
    var accelerationY: Double
    var accelerationZ: Double
    var rotationX: Double // Gyroscope rotation rate
    var rotationY: Double
    var rotationZ: Double
    var roll: Double // Attitude
    var pitch: Double
    var yaw: Double
    var timestamp: Date

    init(id: UUID = UUID(),
         accelerationX: Double = 0.0, accelerationY: Double = 0.0, accelerationZ: Double = 0.0,
         rotationX: Double = 0.0, rotationY: Double = 0.0, rotationZ: Double = 0.0,
         roll: Double = 0.0, pitch: Double = 0.0, yaw: Double = 0.0,
         timestamp: Date = Date()) {
        self.id = id
        self.accelerationX = accelerationX
        self.accelerationY = accelerationY
        self.accelerationZ = accelerationZ
        self.rotationX = rotationX
        self.rotationY = rotationY
        self.rotationZ = rotationZ
        self.roll = roll
        self.pitch = pitch
        self.yaw = yaw
        self.timestamp = timestamp
    }

    // Magnitude of rotation
    var rotationMagnitude: Double {
        sqrt(pow(rotationX, 2) + pow(rotationY, 2) + pow(rotationZ, 2))
    }

    // Magnitude of acceleration
    var accelerationMagnitude: Double {
        sqrt(pow(accelerationX, 2) + pow(accelerationY, 2) + pow(accelerationZ, 2))
    }

    // Format data for display
    var formattedValues: String {
        return """
               Acc (m/s²): X: \(String(format: "%.2f", accelerationX)), Y: \(String(format: "%.2f", accelerationY)), Z: \(String(format: "%.2f", accelerationZ))
               Rot (rad/s): X: \(String(format: "%.2f", rotationX)), Y: \(String(format: "%.2f", rotationY)), Z: \(String(format: "%.2f", rotationZ))
               Att (rad): Roll: \(String(format: "%.2f", roll)), Pitch: \(String(format: "%.2f", pitch)), Yaw: \(String(format: "%.2f", yaw))
               """
    }
    
    // Debug description (primarily for iOS side, but can be consistent)
    var debugDescription: String {
        return String(format: "Acc(X:%.3f,Y:%.3f,Z:%.3f) Rot(X:%.3f,Y:%.3f,Z:%.3f) Att(R:%.3f,P:%.3f,Y:%.3f) TS: %.3f",
                      accelerationX, accelerationY, accelerationZ,
                      rotationX, rotationY, rotationZ,
                      roll, pitch, yaw, timestamp.timeIntervalSince1970)
    }

    static var sample: GyroData {
        GyroData(accelerationX: 0.1, accelerationY: 0.2, accelerationZ: 9.81, // Example gravity component
                 rotationX: 0.05, rotationY: -0.02, rotationZ: 0.1,
                 roll: 0.1, pitch: -0.05, yaw: 0.2)
    }
}
