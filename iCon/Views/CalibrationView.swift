// TennisController/Main App/Views/CalibrationView.swift
import SwiftUI

struct CalibrationView: View {
    @ObservedObject var motionManager: MotionManager
    @State private var calibrationMessage: String = "Place your device on a flat, stable surface and press Calibrate."
    @State private var showSuccessMessage = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: ControllerConstants.UI.defaultSpacing * 2) {
                Image(systemName: "gyroscope")
                    .font(.system(size: 70))
                    .foregroundColor(ControllerConstants.UI.primaryColor)
                
                Text(calibrationMessage)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ControllerConstants.UI.generalPadding)

                // Display current values (post-offset rotation, raw accel/attitude)
                if let currentData = motionManager.currentGyroData {
                     VStack(alignment: .leading, spacing: 4) {
                         Text("Current Values:")
                             .font(.caption).bold().frame(maxWidth: .infinity, alignment: .center)
                         Text("Rot (calibrated): \(String(format: "X: %.2f, Y: %.2f, Z: %.2f", currentData.rotationX, currentData.rotationY, currentData.rotationZ))")
                             .font(.caption.monospaced())
                         Text("Acc (raw): \(String(format: "X: %.2f, Y: %.2f, Z: %.2f", currentData.accelerationX, currentData.accelerationY, currentData.accelerationZ))")
                             .font(.caption.monospaced())
                         Text("Att (raw): \(String(format: "R: %.2f, P: %.2f, Y: %.2f", currentData.roll, currentData.pitch, currentData.yaw))")
                             .font(.caption.monospaced())
                         Text("Rotation Offset: \(String(format: "X: %.2f, Y: %.2f, Z: %.2f", motionManager.calibrationOffset.x, motionManager.calibrationOffset.y, motionManager.calibrationOffset.z))")
                             .font(.caption.monospaced())
                             .foregroundColor(.gray)
                     }
                     .padding(.top, 5)
                     .frame(maxWidth: .infinity)
                }

                Button {
                    performCalibration()
                } label: {
                    Label("Calibrate Gyro Rotation", systemImage: "tuningfork")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, ControllerConstants.UI.generalPadding)
                
                if showSuccessMessage {
                    Text("Gyro Rotation Calibration Successful!")
                        .font(.headline)
                        .foregroundColor(ControllerConstants.UI.secondaryColor)
                        .transition(.opacity.combined(with: .scale))
                }

                Spacer()
            }
            .padding(ControllerConstants.UI.generalPadding)
            .navigationTitle("Calibrate Gyroscope")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                 ToolbarItem(placement: .navigationBarTrailing) {
                     Button("Done") {
                         dismiss()
                     }
                 }
            }
            .onAppear {
                if !motionManager.isMotionActive {
                    motionManager.startMotionUpdates()
                }
                calibrationMessage = "For gyro rotation calibration: Place device on a flat, stable surface, then press 'Calibrate Gyro Rotation'."
            }
        }
    }
    
    private func performCalibration() {
        motionManager.calibrate() // This method in MotionManager handles gyro rotation calibration
        calibrationMessage = "Gyro rotation calibration completed! The current device rotation rate is now considered 'zero'."
        withAnimation {
            showSuccessMessage = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                showSuccessMessage = false
            }
        }
        playHapticFeedback(.success)
    }
    
    private func playHapticFeedback(_ type: ControllerConstants.HapticFeedbackType) {
        let feedbackGenerator: UIFeedbackGenerator
        switch type {
        case .success:
            feedbackGenerator = UINotificationFeedbackGenerator()
            (feedbackGenerator as? UINotificationFeedbackGenerator)?.notificationOccurred(.success)
        // Handle other haptic types if needed
        default:
            return
        }
    }
}

struct CalibrationView_Previews: PreviewProvider {
    static var previews: some View {
        CalibrationView(motionManager: MotionManager())
    }
}
