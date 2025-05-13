// TennisController/Main App/Views/ControllerView.swift
import SwiftUI
import Combine

struct ControllerView: View {
    @StateObject private var motionManager = MotionManager()
    @StateObject private var connectionManager = ControllerConnectionManager()

    @State private var showingConnectionSheet = false
    @State private var showingSettingsSheet = false
    @State private var showingCalibrationSheet = false
    
    // Using AppStorage for user preference on auto-sending data
    @AppStorage("autoSendDataEnabled") private var autoSendDataEnabled: Bool = true
    @AppStorage("sendDataInterval") private var sendDataInterval: Double = ControllerConstants.motionUpdateInterval // Default to motion update interval

    private var dataSendCancellable: AnyCancellable?
    @State private var dataSendTimer: Timer?

    init() {
        // If using Combine for timed data sending
        // self.dataSendCancellable = Timer.publish(every: sendDataInterval, on: .main, in: .common)
        //     .autoconnect()
        //     .sink { [weak self] _ in
        //         guard let self = self, self.autoSendDataEnabled else { return }
        //         self.sendMotionData()
        //     }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: ControllerConstants.UI.defaultSpacing) {
                ConnectionStatusHeader(connectionManager: connectionManager,
                                       onTap: { showingConnectionSheet = true })
                
                LiveGyroDataView(motionManager: motionManager)

                Spacer()
                
                MotionErrorDisplay(motionManager: motionManager)

                // Manual Send Button (if auto-send is off or for specific actions)
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
            .padding(.top, ControllerConstants.UI.generalPadding) // Add padding to top content
            .padding(.bottom) // Padding for footer
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
                SettingsView(motionManager: motionManager)
            }
            .sheet(isPresented: $showingCalibrationSheet) {
                CalibrationView(motionManager: motionManager)
            }
            .onAppear(perform: setupController)
            .onDisappear(perform: teardownController)
            .onChange(of: connectionManager.connectionState) { newState in
                 handleConnectionStateChange(newState)
            }
            .onChange(of: autoSendDataEnabled) { enabled in
                configureDataSending(autoEnabled: enabled, interval: sendDataInterval)
            }
            .onChange(of: sendDataInterval) { interval in
                configureDataSending(autoEnabled: autoSendDataEnabled, interval: interval)
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private func setupController() {
        motionManager.startMotionUpdates()
        if connectionManager.connectionState == .disconnected || connectionManager.connectionState == .failed {
            // connectionManager.startBrowsing() // Start browsing automatically or let user do it via sheet
        }
        configureDataSending(autoEnabled: autoSendDataEnabled, interval: sendDataInterval)
    }
    
    private func teardownController() {
        motionManager.stopMotionUpdates()
        dataSendTimer?.invalidate()
        dataSendTimer = nil
        // connectionManager.stopBrowsing() // Or disconnect if appropriate
    }
    
    private func configureDataSending(autoEnabled: Bool, interval: TimeInterval) {
        dataSendTimer?.invalidate()
        dataSendTimer = nil
        if autoEnabled {
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
        // Basic haptic implementation
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
        }
    }
}

// MARK: - Subviews for ControllerView
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
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(8)
        .padding(.horizontal, ControllerConstants.UI.generalPadding) // Outer padding for the entire header
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

private struct LiveGyroDataView: View {
    @ObservedObject var motionManager: MotionManager

    var body: some View {
        VStack {
            Text("Live Gyroscope Data")
                .font(.title3).bold()
            
            if let data = motionManager.currentGyroData {
                HStack(spacing: 15) {
                    Text(String(format: "X: %.2f", data.x))
                    Text(String(format: "Y: %.2f", data.y))
                    Text(String(format: "Z: %.2f", data.z))
                }
                .font(.system(.body, design: .monospaced))
                Text(String(format: "Magnitude: %.2f", data.magnitude))
                    .font(.system(.callout, design: .monospaced).bold())
                    .padding(.top, 2)
            } else {
                Text("Awaiting motion data...")
                    .foregroundColor(ControllerConstants.UI.secondaryTextColor)
                    .italic()
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
                Label("Calibrate", systemImage: "gyroscope")
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

// MARK: - Preview
struct ControllerView_Previews: PreviewProvider {
    static var previews: some View {
        ControllerView()
    }
}
