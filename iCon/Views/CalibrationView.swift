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

                if let currentData = motionManager.currentGyroData {
                     VStack {
                         Text("Current Raw Gyro Values:")
                             .font(.caption).bold()
                         Text(currentData.formattedValues) // Note: This will show calibrated values if already calibrated
                             .font(.caption.monospaced())
                         Text("Current Offset: \(String(format: "X: %.2f, Y: %.2f, Z: %.2f", motionManager.calibrationOffset.x, motionManager.calibrationOffset.y, motionManager.calibrationOffset.z))")
                             .font(.caption.monospaced())
                             .foregroundColor(.gray)
                     }
                     .padding(.top, 5)
                }

                Button {
                    performCalibration()
                } label: {
                    Label("Calibrate Now", systemImage: "tuningfork")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, ControllerConstants.UI.generalPadding)
                
                if showSuccessMessage {
                    Text("Calibration Successful!")
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
                    motionManager.startMotionUpdates() // Start motion for live values during calibration
                }
                calibrationMessage = "Place your device on a flat, stable surface, then press 'Calibrate Now'."
            }
            // Decide if motion should stop on disappear or keep running if ControllerView expects it.
        }
    }
    
    private func performCalibration() {
        motionManager.calibrate()
        calibrationMessage = "Calibration completed! The current device orientation is now considered 'zero'."
        withAnimation {
            showSuccessMessage = true
        }
        // Optional: auto-dismiss success message or the whole view
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                showSuccessMessage = false
            }
        }
        playHapticFeedback(.success)
    }
    
    private func playHapticFeedback(_ type: ControllerConstants.HapticFeedbackType) {
        // Basic haptic implementation
        let feedbackGenerator: UIFeedbackGenerator
        switch type {
        case .success:
            feedbackGenerator = UINotificationFeedbackGenerator()
            (feedbackGenerator as? UINotificationFeedbackGenerator)?.notificationOccurred(.success)
        default: // Add more cases as needed from your HapticFeedbackType enum
            return
        }
    }
}

struct CalibrationView_Previews: PreviewProvider {
    static var previews: some View {
        CalibrationView(motionManager: MotionManager())
    }
}
