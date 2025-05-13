// TennisController/Main App/Models/GyroData.swift
import Foundation

struct GyroData: Codable, Identifiable, Equatable {
    var id = UUID()
    var x: Double
    var y: Double
    var z: Double
    var timestamp: Date

    init(x: Double = 0.0, y: Double = 0.0, z: Double = 0.0, timestamp: Date = Date()) {
        self.x = x
        self.y = y
        self.z = z
        self.timestamp = timestamp
    }

    // Calculate the magnitude of movement
    var magnitude: Double {
        return sqrt(pow(x, 2) + pow(y, 2) + pow(z, 2))
    }

    // Format data for display
    var formattedValues: String {
        return String(format: "X: %.2f, Y: %.2f, Z: %.2f", x, y, z)
    }
    
    var debugDescription: String {
        return String(format: "GyroData(X: %.3f, Y: %.3f, Z: %.3f, Mag: %.3f, TS: %.3f)", x, y, z, magnitude, timestamp.timeIntervalSince1970)
    }

    // For preview and testing
    static var sample: GyroData {
        return GyroData(x: 0.42, y: -0.18, z: 0.91)
    }
}
