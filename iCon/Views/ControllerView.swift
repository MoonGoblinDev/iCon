// TennisController/Main App/Views/ControllerView.swift
import SwiftUI
import Combine

struct ControllerView: View {
    @StateObject private var motionManager = MotionManager()
    @StateObject private var connectionManager = ControllerConnectionManager()

    @State private var showingConnectionSheet = false
    @State private var showingSettingsSheet = false
    @State private var showingCalibrationSheet = false
    
    @AppStorage("autoSendDataEnabled") private var autoSendDataEnabled: Bool = true
    @AppStorage("sendDataInterval") private var sendDataInterval: Double = ControllerConstants.motionUpdateInterval

    @State private var dataSendTimer: Timer? // Changed from AnyCancellable

    // Removed init with Combine timer publisher, will use Timer directly

    var body: some View {
        NavigationView {
            VStack(spacing: ControllerConstants.UI.defaultSpacing) {
                ConnectionStatusHeader(connectionManager: connectionManager,
                                       onTap: { showingConnectionSheet = true })
                
                // Updated LiveGyroDataView is defined below
                LiveMotionDataView(motionManager: motionManager)

                Spacer()
                
                MotionErrorDisplay(motionManager: motionManager)

                if !autoSendDataEnabled {
                    Button("Send Swing Data") {
                        sendMotionData()
                        playHapticFeedback(.mediumImpact)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(connectionManager.connectionState != .connected)
                    .padding(.horizontal, ControllerConstants.UI.generalPadding)
                }
                
                ControllerActionsFooter(
                    onCalibrateTap: { showingCalibrationSheet = true },
                    isMotionActive: motionManager.isMotionActive,
                    toggleMotionUpdates: toggleMotion
                )
            }
            .padding(.top, ControllerConstants.UI.generalPadding)
            .padding(.bottom)
            .navigationTitle("Tennis Paddle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showingSettingsSheet = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingConnectionSheet = true } label: {
                        Image(systemName: connectionManager.connectionState == .connected ? "wifi" : "wifi.slash")
                            .foregroundColor(connectionManager.connectionState == .connected ? ControllerConstants.UI.secondaryColor : ControllerConstants.UI.warningColor)
                    }
                }
            }
            .sheet(isPresented: $showingConnectionSheet) {
                ConnectionSetupView(connectionManager: connectionManager)
            }
            .sheet(isPresented: $showingSettingsSheet) {
                SettingsView(motionManager: motionManager) // Pass motion manager if settings affect it directly
            }
            .sheet(isPresented: $showingCalibrationSheet) {
                CalibrationView(motionManager: motionManager)
            }
            .onAppear(perform: setupController)
            .onDisappear(perform: teardownController)
            .onChange(of: connectionManager.connectionState) { oldValue, newState in
                             // We only need the newState here for the existing logic
                             handleConnectionStateChange(newState)
                        }
                        .onChange(of: autoSendDataEnabled) { oldValue, newValue in
                            // We only need the newValue here
                            configureDataSending(autoEnabled: newValue, interval: sendDataInterval)
                        }
                        .onChange(of: sendDataInterval) { oldValue, newValue in
                            // We only need the newValue here
                            configureDataSending(autoEnabled: autoSendDataEnabled, interval: newValue)
                        }
        }
        .navigationViewStyle(.stack)
    }
    
    private func setupController() {
        motionManager.startMotionUpdates()
        // Auto-start browsing or let user initiate via sheet
        // if connectionManager.connectionState == .disconnected || connectionManager.connectionState == .failed {
        //     connectionManager.startBrowsing()
        // }
        configureDataSending(autoEnabled: autoSendDataEnabled, interval: sendDataInterval)
    }
    
    private func teardownController() {
        motionManager.stopMotionUpdates()
        dataSendTimer?.invalidate()
        dataSendTimer = nil
        // Optionally stop browsing or disconnect
        // if connectionManager.isBrowsing { connectionManager.stopBrowsing() }
        // if connectionManager.connectionState == .connected { connectionManager.disconnect() }
    }
    
    private func configureDataSending(autoEnabled: Bool, interval: TimeInterval) {
        dataSendTimer?.invalidate()
        dataSendTimer = nil
        if autoEnabled, interval > 0 { // Ensure interval is valid
            dataSendTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                sendMotionData()
            }
        }
    }

    private func sendMotionData() {
        if connectionManager.connectionState == .connected, let data = motionManager.currentGyroData {
            connectionManager.sendGyroData(data)
        }
    }
    
    private func toggleMotion() {
        if motionManager.isMotionActive {
            motionManager.stopMotionUpdates()
        } else {
            motionManager.startMotionUpdates()
        }
    }
    
    private func handleConnectionStateChange(_ newState: ControllerConnectionState) {
        switch newState {
        case .connected:
            playHapticFeedback(.success)
        case .disconnected, .failed:
            playHapticFeedback(.error)
        default:
            break
        }
    }
    
    private func playHapticFeedback(_ type: ControllerConstants.HapticFeedbackType) {
        let feedbackGenerator: UIFeedbackGenerator
        switch type {
        case .success:
            feedbackGenerator = UINotificationFeedbackGenerator()
            (feedbackGenerator as? UINotificationFeedbackGenerator)?.notificationOccurred(.success)
        case .warning:
            feedbackGenerator = UINotificationFeedbackGenerator()
            (feedbackGenerator as? UINotificationFeedbackGenerator)?.notificationOccurred(.warning)
        case .error:
            feedbackGenerator = UINotificationFeedbackGenerator()
            (feedbackGenerator as? UINotificationFeedbackGenerator)?.notificationOccurred(.error)
        case .selection:
            feedbackGenerator = UISelectionFeedbackGenerator()
            (feedbackGenerator as? UISelectionFeedbackGenerator)?.selectionChanged()
        case .lightImpact:
            feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
            (feedbackGenerator as? UIImpactFeedbackGenerator)?.impactOccurred()
        case .mediumImpact:
            feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
            (feedbackGenerator as? UIImpactFeedbackGenerator)?.impactOccurred()
        case .heavyImpact:
            feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
            (feedbackGenerator as? UIImpactFeedbackGenerator)?.impactOccurred()
        // Ensure all cases of HapticFeedbackType are handled or add a default.
        }
    }
}

// MARK: - Subviews for ControllerView (LiveMotionDataView updated)
private struct ConnectionStatusHeader: View {
    @ObservedObject var connectionManager: ControllerConnectionManager
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                Text("Status: \(connectionManager.connectionState.rawValue)")
                    .font(.headline)
                    .foregroundColor(ControllerConstants.UI.textColor)
                if connectionManager.connectionState == .connected, let hostName = connectionManager.hostPeerID?.displayName {
                    Text("to \(hostName)")
                        .font(.subheadline)
                        .foregroundColor(ControllerConstants.UI.secondaryTextColor)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, ControllerConstants.UI.generalPadding)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground)) // Use system color
        .cornerRadius(8)
        .padding(.horizontal, ControllerConstants.UI.generalPadding)
    }

    private var statusColor: Color {
        switch connectionManager.connectionState {
        case .disconnected: return .gray
        case .searching: return ControllerConstants.UI.warningColor
        case .connecting: return ControllerConstants.UI.primaryColor
        case .connected: return ControllerConstants.UI.secondaryColor
        case .failed: return ControllerConstants.UI.destructiveColor
        }
    }
}

// Renamed and updated LiveGyroDataView to LiveMotionDataView
private struct LiveMotionDataView: View {
    @ObservedObject var motionManager: MotionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Live Motion Data")
                .font(.title3).bold()
                .frame(maxWidth: .infinity, alignment: .center)
            
            if let data = motionManager.currentGyroData {
                Group {
                    Text("Acceleration (Gs):") // Clarify units, CM userAcceleration is in Gs
                        .font(.caption).bold()
                    HStack(spacing: 10) {
                        Text(String(format: "X: %.2f", data.accelerationX))
                        Text(String(format: "Y: %.2f", data.accelerationY))
                        Text(String(format: "Z: %.2f", data.accelerationZ))
                    }
                    .font(.system(.callout, design: .monospaced))

                    Text("Rotation Rate (rad/s):")
                        .font(.caption).bold().padding(.top, 4)
                    HStack(spacing: 10) {
                        Text(String(format: "X: %.2f", data.rotationX))
                        Text(String(format: "Y: %.2f", data.rotationY))
                        Text(String(format: "Z: %.2f", data.rotationZ))
                    }
                    .font(.system(.callout, design: .monospaced))

                    Text("Attitude (radians):")
                        .font(.caption).bold().padding(.top, 4)
                    HStack(spacing: 10) {
                        Text(String(format: "Roll: %.2f", data.roll))
                        Text(String(format: "Pitch: %.2f", data.pitch))
                        Text(String(format: "Yaw: %.2f", data.yaw))
                    }
                    .font(.system(.callout, design: .monospaced))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

            } else {
                Text("Awaiting motion data...")
                    .foregroundColor(ControllerConstants.UI.secondaryTextColor)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(10)
        .padding(.horizontal, ControllerConstants.UI.generalPadding)
    }
}

private struct MotionErrorDisplay: View {
    @ObservedObject var motionManager: MotionManager
    var body: some View {
        if let error = motionManager.motionError {
            Text("Motion Error: \(error)")
                .font(.caption)
                .foregroundColor(ControllerConstants.UI.destructiveColor)
                .padding(.horizontal, ControllerConstants.UI.generalPadding)
                .multilineTextAlignment(.center)
        }
    }
}

private struct ControllerActionsFooter: View {
    var onCalibrateTap: () -> Void
    var isMotionActive: Bool
    var toggleMotionUpdates: () -> Void

    var body: some View {
        HStack(spacing: ControllerConstants.UI.defaultSpacing) {
            Button(action: onCalibrateTap) {
                Label("Calibrate Gyro", systemImage: "gyroscope") // Clarified Calibration target
            }
            .buttonStyle(SecondaryButtonStyle())
            
            Button(action: toggleMotionUpdates) {
                Label(isMotionActive ? "Pause Motion" : "Start Motion",
                      systemImage: isMotionActive ? "pause.circle.fill" : "play.circle.fill")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(.horizontal, ControllerConstants.UI.generalPadding)
    }
}

struct ControllerView_Previews: PreviewProvider {
    static var previews: some View {
        ControllerView()
    }
}
