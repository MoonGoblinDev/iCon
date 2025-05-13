// TennisController/Shared/Utilities/Constants.swift
import Foundation
import SwiftUI

enum ControllerConstants {
    static let appName = "Tennis Controller"
    static let appClipName = "Tennis Controller Quick Play"
    static let appVersion = "1.0.0"

    // Network configuration (must match Host app's Constants.serviceType)
    static let serviceType = "tennis-game"
    static let connectionTimeout: TimeInterval = 30.0

    // Motion Data
    static let motionUpdateInterval: TimeInterval = 1.0 / 60.0 // 60 Hz (adjust as needed for performance/accuracy)

    struct UI {
        static let primaryColor = Color.blue
        static let secondaryColor = Color.green
        static let destructiveColor = Color.red
        static let warningColor = Color.orange
        static let backgroundColor = Color(.systemGroupedBackground)
        static let textColor = Color(.label)
        static let secondaryTextColor = Color(.secondaryLabel)

        static let buttonCornerRadius: CGFloat = 10
        static let generalPadding: CGFloat = 16
        static let defaultSpacing: CGFloat = 12
    }

    enum HapticFeedbackType {
        case success
        case warning
        case error
        case selection
        case lightImpact
        case mediumImpact
        case heavyImpact
    }
}

// Shared Button Styles (can be used by both main app and app clip)
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(ControllerConstants.UI.generalPadding / 1.5)
            .frame(maxWidth: .infinity)
            .background(ControllerConstants.UI.primaryColor)
            .foregroundColor(.white)
            .cornerRadius(ControllerConstants.UI.buttonCornerRadius)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(ControllerConstants.UI.generalPadding / 1.5)
            .frame(maxWidth: .infinity)
            .background(ControllerConstants.UI.backgroundColor)
            .foregroundColor(ControllerConstants.UI.primaryColor)
            .cornerRadius(ControllerConstants.UI.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: ControllerConstants.UI.buttonCornerRadius)
                    .stroke(ControllerConstants.UI.primaryColor, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(), value: configuration.isPressed)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(ControllerConstants.UI.generalPadding / 1.5)
            .frame(maxWidth: .infinity)
            .background(ControllerConstants.UI.destructiveColor)
            .foregroundColor(.white)
            .cornerRadius(ControllerConstants.UI.buttonCornerRadius)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(), value: configuration.isPressed)
    }
}
