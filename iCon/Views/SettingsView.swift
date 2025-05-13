// TennisController/Main App/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var motionManager: MotionManager
    @Environment(\.dismiss) var dismiss

    // User-configurable settings backed by AppStorage
    @AppStorage("motionUpdateFrequencyHz") private var motionUpdateFrequencyHz: Int = Int(1.0 / ControllerConstants.motionUpdateInterval) // e.g., 60
    @AppStorage("hapticFeedbackEnabled") private var hapticFeedbackEnabled: Bool = true
    @AppStorage("autoSendDataEnabled") private var autoSendDataEnabled: Bool = true // From ControllerView
    @AppStorage("sendDataIntervalSeconds") private var sendDataIntervalSeconds: Double = ControllerConstants.motionUpdateInterval // From ControllerView

    let frequencyOptionsHz: [Int] = [30, 60, 90, 120]
    let sendIntervalOptionsSeconds: [Double] = [1.0/15.0, 1.0/30.0, 1.0/60.0, 1.0/90.0] // Approx 15Hz, 30Hz, 60Hz, 90Hz

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Motion Sensor")) {
                    Picker("Motion Update Frequency", selection: $motionUpdateFrequencyHz) {
                        ForEach(frequencyOptionsHz, id: \.self) { freq in
                            Text("\(freq) Hz").tag(freq)
                        }
                    }
                    .onChange(of: motionUpdateFrequencyHz) { newValue in
                        motionManager.setUpdateInterval(1.0 / Double(newValue))
                    }
                    
                    Button("Re-Calibrate Gyroscope") {
                        // Optionally navigate to a dedicated calibration screen or show instructions
                        motionManager.calibrate()
                        // Provide feedback
                    }
                }

                Section(header: Text("Data Transmission")) {
                    Toggle("Auto-Send Gyro Data", isOn: $autoSendDataEnabled)
                    
                    if autoSendDataEnabled {
                        Picker("Send Data Interval", selection: $sendDataIntervalSeconds) {
                            ForEach(sendIntervalOptionsSeconds, id: \.self) { interval in
                                Text("\(String(format: "%.0f", 1.0/interval)) updates/sec (\(String(format: "%.2f", interval*1000)) ms)").tag(interval)
                            }
                        }
                    }
                }

                Section(header: Text("Feedback")) {
                    Toggle("Enable Haptic Feedback", isOn: $hapticFeedbackEnabled)
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("App Name")
                        Spacer()
                        Text(ControllerConstants.appName)
                    }
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text(ControllerConstants.appVersion)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(motionManager: MotionManager())
    }
}
