// TennisController/Main App/Managers/ConnectionManager.swift
import Foundation
import MultipeerConnectivity
import Combine
import os.log

enum ControllerConnectionState: String, CaseIterable {
    case disconnected = "Disconnected"
    case searching = "Searching for Host..."
    case connecting = "Connecting..."
    case connected = "Connected"
    case failed = "Connection Failed"
}

class ControllerConnectionManager: NSObject, ObservableObject {
    private let serviceType = ControllerConstants.serviceType
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.example.TennisController", category: "ControllerConnectionManager")

    private var localPeerID: MCPeerID
    private var session: MCSession
    private var serviceBrowser: MCNearbyServiceBrowser

    @Published var connectionState: ControllerConnectionState = .disconnected
    @Published var hostPeerID: MCPeerID?
    @Published var connectionError: String?

    // Published list of found peers for potential UI selection
    @Published var foundPeers: [MCPeerID] = []
    
    private var autoConnectTimer: Timer?

    override init() {
        self.localPeerID = MCPeerID(displayName: UIDevice.current.name)
        self.session = MCSession(peer: localPeerID, securityIdentity: nil, encryptionPreference: .required)
        self.serviceBrowser = MCNearbyServiceBrowser(peer: localPeerID, serviceType: serviceType)
        super.init()
        self.session.delegate = self
        self.serviceBrowser.delegate = self
    }

    func startBrowsing() {
        logger.info("Starting to browse for peers with service type: \(self.serviceType)")
        resetConnectionState()
        foundPeers.removeAll() // Clear previous list
        serviceBrowser.startBrowsingForPeers()
        DispatchQueue.main.async {
            self.connectionState = .searching
        }
    }

    func stopBrowsing() {
        logger.info("Stopping peer browsing.")
        serviceBrowser.stopBrowsingForPeers()
        if connectionState == .searching {
            DispatchQueue.main.async {
                self.connectionState = .disconnected
            }
        }
    }
    
    func invitePeer(_ peerID: MCPeerID) {
        guard connectionState == .searching || connectionState == .disconnected || connectionState == .failed else {
            logger.info("Cannot invite peer: current state is \(self.connectionState.rawValue)")
            return
        }
        logger.info("Inviting peer: \(peerID.displayName)")
        serviceBrowser.invitePeer(peerID, to: self.session, withContext: nil, timeout: ControllerConstants.connectionTimeout)
        DispatchQueue.main.async {
            self.connectionState = .connecting
            self.hostPeerID = peerID // Tentatively set
        }
    }

    func disconnect() {
        logger.info("Disconnecting session.")
        session.disconnect() // This will trigger session state changes
        // State updated via delegate
    }

    func sendGyroData(_ gyroData: GyroData) {
        guard let connectedHost = hostPeerID, session.connectedPeers.contains(connectedHost) else {
            logger.warning("Cannot send data: No host connected or hostPeerID mismatch.")
            return
        }

        do {
            let data = try JSONEncoder().encode(gyroData)
            try session.send(data, toPeers: [connectedHost], with: .unreliable) // .unreliable for frequent updates
            //logger.debug("Sent gyro data: \(gyroData.debugDescription)")
        } catch {
            let errorMsg = "Error sending gyro data: \(error.localizedDescription)"
            logger.error("\(errorMsg)")
            DispatchQueue.main.async {
                 self.connectionError = errorMsg
                 // Consider if this error should change connectionState to .failed or .disconnected
            }
        }
    }
    
    private func resetConnectionState() {
        DispatchQueue.main.async {
            self.hostPeerID = nil
            self.connectionError = nil
            // Don't reset foundPeers here unless intended when restarting browse
        }
    }
}

// MARK: - MCSessionDelegate
extension ControllerConnectionManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.logger.info("Peer \(peerID.displayName) changed state to \(self.MCSessionStateString(state))")
            switch state {
            case .connected:
                // Ensure this is the peer we intended to connect to, or the first successful connection
                if self.hostPeerID == nil || self.hostPeerID == peerID {
                    self.hostPeerID = peerID // Confirm host
                    self.connectionState = .connected
                    self.connectionError = nil
                    self.logger.info("Connected to host: \(peerID.displayName)")
                    self.serviceBrowser.stopBrowsingForPeers() // Stop browsing once connected
                    self.foundPeers.removeAll() // Clear list as we are connected
                } else {
                    // Connected to an unexpected peer, might happen with multiple invites
                    // Decide how to handle: disconnect or accept. For now, log.
                    self.logger.warning("Connected to an unexpected peer \(peerID.displayName) while host was \(self.hostPeerID?.displayName ?? "nil"). Maintaining current host.")
                }

            case .connecting:
                // Only set to connecting if we are not already connected to someone else
                if self.connectionState != .connected { // or self.hostPeerID == peerID
                    self.connectionState = .connecting
                }

            case .notConnected:
                // If this was our confirmed host
                if self.hostPeerID == peerID {
                    self.logger.info("Disconnected from host: \(peerID.displayName). Current state: \(self.connectionState.rawValue)")
                    let previousState = self.connectionState
                    self.resetConnectionState() // Clear host info

                    // Determine if disconnection was failure or intentional
                    if previousState == .connecting { // If was connecting and failed
                        self.connectionState = .failed
                        self.connectionError = "Connection to \(peerID.displayName) failed or was rejected."
                    } else { // Was connected or other state
                        self.connectionState = .disconnected
                        // Optionally, could set an error if the disconnection was unexpected
                        // self.connectionError = "Lost connection to \(peerID.displayName)."
                    }
                } else if self.connectionState == .connecting && (self.hostPeerID == nil || self.hostPeerID == peerID){
                    // If we were trying to connect to this peer and it failed before full connection
                    self.logger.info("Failed to connect to \(peerID.displayName).")
                    self.resetConnectionState()
                    self.connectionState = .failed
                    self.connectionError = "Failed to establish connection with \(peerID.displayName)."
                }
                // If a peer from foundPeers list drops, MCSession won't notify directly unless an invite was sent.
                // MCNearbyServiceBrowser's lostPeer handles non-connected peers.

            @unknown default:
                self.logger.warning("Unknown MCSessionState: \(state.rawValue) for peer \(peerID.displayName)")
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        logger.debug("Received data from \(peerID.displayName), but controller does not expect data.")
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { /* Not used */ }
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { /* Not used */ }
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) { /* Not used */ }
    
    // Helper function to convert MCSessionState to String for logging
    private func MCSessionStateString(_ state: MCSessionState) -> String {
        switch state {
        case .notConnected: return "NotConnected"
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension ControllerConnectionManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        logger.info("Found potential host: \(peerID.displayName)")
        DispatchQueue.main.async {
            if !self.foundPeers.contains(where: { $0.displayName == peerID.displayName }) {
                self.foundPeers.append(peerID)
            }
            // For this implementation, we let the user pick from `ConnectionView`
            // Or, if you want to auto-connect to the first found peer:
            // if self.connectionState == .searching && self.hostPeerID == nil {
            //    self.invitePeer(peerID)
            // }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        logger.info("Lost potential host: \(peerID.displayName)")
        DispatchQueue.main.async {
            self.foundPeers.removeAll(where: { $0.displayName == peerID.displayName })
            // If this peer was the one we were trying to connect to (but not yet fully connected)
            // and it's lost, the session delegate's .notConnected state change for that peer
            // should handle setting the state to failed.
            // However, if we just "lost" it from browsing before an invite was fully processed by session,
            // we might need to reset hostPeerID if it was tentatively set.
            if self.hostPeerID == peerID && self.connectionState == .connecting {
                self.logger.info("Peer \(peerID.displayName) was lost during connection attempt.")
                // The MCSessionDelegate's state change to .notConnected should ultimately handle this.
                // To be safe, one might ensure UI reflects this possibility if session delegate is slow.
                // self.connectionState = .failed
                // self.connectionError = "Host \(peerID.displayName) disappeared during connection attempt."
                // self.hostPeerID = nil
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        let errorMsg = "Failed to start browsing for hosts: \(error.localizedDescription)"
        logger.error("\(errorMsg)")
        DispatchQueue.main.async {
            self.connectionError = errorMsg
            self.connectionState = .failed
        }
    }
}
