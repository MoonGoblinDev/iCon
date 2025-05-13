// TennisController/Main App/Views/ConnectionSetupView.swift
import SwiftUI
import MultipeerConnectivity

struct ConnectionSetupView: View {
    @ObservedObject var connectionManager: ControllerConnectionManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: ControllerConstants.UI.defaultSpacing) {
                
                CurrentConnectionStatusView(connectionManager: connectionManager)

                if let error = connectionManager.connectionError {
                    ErrorMessageView(message: error)
                }

                if connectionManager.connectionState == .searching && connectionManager.foundPeers.isEmpty {
                    ProgressView("Searching for hosts...")
                        .padding()
                } else if !connectionManager.foundPeers.isEmpty && connectionManager.connectionState != .connected {
                    List {
                        Section("Available Hosts") {
                            ForEach(connectionManager.foundPeers, id: \.self) { peer in
                                Button(action: {
                                    connectionManager.invitePeer(peer)
                                }) {
                                    HStack {
                                        Text(peer.displayName)
                                        Spacer()
                                        Image(systemName: "wifi")
                                    }
                                }
                                .disabled(connectionManager.connectionState == .connecting)
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                } else if connectionManager.connectionState == .connected {
                     Text("Successfully connected!")
                        .font(.title3)
                        .foregroundColor(ControllerConstants.UI.secondaryColor)
                        .padding()
                }

                Spacer()

                ActionButtonsView(connectionManager: connectionManager, dismissAction: { dismiss() })
            }
            .padding(.vertical)
            .navigationTitle("Connect to Host")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                 ToolbarItem(placement: .navigationBarTrailing) {
                     Button("Done") {
                         dismiss()
                     }
                 }
            }
            .onAppear {
                if connectionManager.connectionState == .disconnected || connectionManager.connectionState == .failed && connectionManager.foundPeers.isEmpty {
                    connectionManager.startBrowsing()
                }
            }
            .onDisappear {
                // Decide if browsing should stop when sheet is dismissed
                // if connectionManager.connectionState == .searching {
                //     connectionManager.stopBrowsing()
                // }
            }
        }
    }
}

// MARK: - Subviews for ConnectionSetupView
private struct CurrentConnectionStatusView: View {
    @ObservedObject var connectionManager: ControllerConnectionManager

    var body: some View {
        VStack {
            Image(systemName: iconName)
                .font(.system(size: 50))
                .foregroundColor(iconColor)
                .padding(.bottom, 2)
            Text(statusText)
                .font(.title2)
                .foregroundColor(ControllerConstants.UI.textColor)
            if connectionManager.connectionState == .connected, let hostName = connectionManager.hostPeerID?.displayName {
                Text("To: \(hostName)")
                    .font(.subheadline)
                    .foregroundColor(ControllerConstants.UI.secondaryTextColor)
            }
        }
        .padding()
    }

    private var iconName: String {
        switch connectionManager.connectionState {
        case .disconnected: return "wifi.slash"
        case .searching: return "magnifyingglass.circle.fill"
        case .connecting: return "arrow.triangle.2.circlepath.circle.fill"
        case .connected: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch connectionManager.connectionState {
        case .disconnected: return .gray
        case .searching: return ControllerConstants.UI.warningColor
        case .connecting: return ControllerConstants.UI.primaryColor
        case .connected: return ControllerConstants.UI.secondaryColor
        case .failed: return ControllerConstants.UI.destructiveColor
        }
    }
    
    private var statusText: String {
        // Customized status text if needed
        return connectionManager.connectionState.rawValue
    }
}

private struct ErrorMessageView: View {
    let message: String
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.circle")
                .foregroundColor(ControllerConstants.UI.destructiveColor)
            Text(message)
                .font(.callout)
                .foregroundColor(ControllerConstants.UI.destructiveColor)
        }
        .padding(ControllerConstants.UI.generalPadding / 2)
        .frame(maxWidth: .infinity)
        .background(ControllerConstants.UI.destructiveColor.opacity(0.15))
        .cornerRadius(ControllerConstants.UI.buttonCornerRadius / 2)
        .padding(.horizontal, ControllerConstants.UI.generalPadding)
    }
}

private struct ActionButtonsView: View {
    @ObservedObject var connectionManager: ControllerConnectionManager
    var dismissAction: () -> Void

    var body: some View {
        VStack(spacing: ControllerConstants.UI.defaultSpacing) {
            switch connectionManager.connectionState {
            case .disconnected, .failed:
                Button("Search for Host") {
                    connectionManager.startBrowsing()
                }
                .buttonStyle(PrimaryButtonStyle())
            case .searching:
                Button("Stop Searching") {
                    connectionManager.stopBrowsing()
                }
                .buttonStyle(SecondaryButtonStyle())
            case .connecting:
                // Could have a "Cancel Connection Attempt" button here
                ProgressView("Connecting...")
                    .padding()
                Button("Cancel Connection") {
                    connectionManager.disconnect() // This effectively cancels
                    connectionManager.startBrowsing() // Go back to searching
                }
                .buttonStyle(DestructiveButtonStyle())
            case .connected:
                Button("Disconnect from Host") {
                    connectionManager.disconnect()
                }
                .buttonStyle(DestructiveButtonStyle())
            }
        }
        .padding(.horizontal, ControllerConstants.UI.generalPadding)
    }
}

// MARK: - Preview
struct ConnectionSetupView_Previews: PreviewProvider {
    static var previews: some View {
        // Disconnected State
        let manager = ControllerConnectionManager()
        ConnectionSetupView(connectionManager: manager)
            .previewDisplayName("Disconnected")

        // Searching State with Peers
        let searchingManager = ControllerConnectionManager()
        //searchingManager.connectionState = .searching
        //searchingManager.foundPeers = [MCPeerID(displayName: "Mac Host 1"), MCPeerID(displayName: "Mac Host 2")]
        ConnectionSetupView(connectionManager: searchingManager)
            .previewDisplayName("Searching with Peers")
        
        // Connected State
        let connectedManager = ControllerConnectionManager()
        //connectedManager.connectionState = .connected
        //connectedManager.hostPeerID = MCPeerID(displayName: "MacBook Pro Host")
        ConnectionSetupView(connectionManager: connectedManager)
            .previewDisplayName("Connected")
    }
}
