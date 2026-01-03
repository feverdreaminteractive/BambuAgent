import SwiftUI

// MARK: - Colors
extension Color {
    static let bambuPrimary = Color(red: 0.0, green: 0.8, blue: 0.4) // Bambu green
    static let bambuSecondary = Color(red: 0.1, green: 0.6, blue: 0.9) // Tech blue
    static let bambuAccent = Color(red: 1.0, green: 0.5, blue: 0.0) // Orange for highlights

    // Status colors
    static let statusSuccess = Color.green
    static let statusWarning = Color.orange
    static let statusError = Color.red
    static let statusInfo = Color.blue

    // Background colors for dark mode
    static let surfacePrimary = Color(UIColor.systemBackground)
    static let surfaceSecondary = Color(UIColor.secondarySystemBackground)
    static let surfaceTertiary = Color(UIColor.tertiarySystemBackground)
}

// MARK: - Typography
struct BambuTextStyle {
    static let largeTitle = Font.largeTitle.weight(.bold)
    static let title = Font.title.weight(.semibold)
    static let title2 = Font.title2.weight(.medium)
    static let headline = Font.headline.weight(.semibold)
    static let body = Font.body
    static let callout = Font.callout
    static let caption = Font.caption.weight(.medium)
    static let footnote = Font.footnote
}

// MARK: - Spacing
struct BambuSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius
struct BambuRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

// MARK: - Custom Button Styles
struct BambuPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, BambuSpacing.lg)
            .padding(.vertical, BambuSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: BambuRadius.md)
                    .fill(Color.bambuPrimary)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct BambuSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.bambuPrimary)
            .padding(.horizontal, BambuSpacing.lg)
            .padding(.vertical, BambuSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: BambuRadius.md)
                    .stroke(Color.bambuPrimary, lineWidth: 2)
                    .background(Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct BambuDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, BambuSpacing.lg)
            .padding(.vertical, BambuSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: BambuRadius.md)
                    .fill(Color.statusError)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Card Style
struct BambuCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(BambuSpacing.lg)
            .background(Color.surfaceSecondary)
            .cornerRadius(BambuRadius.lg)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Status Indicator
struct StatusIndicator: View {
    enum Status {
        case idle, printing, paused, error, success

        var color: Color {
            switch self {
            case .idle: return .gray
            case .printing: return .bambuPrimary
            case .paused: return .statusWarning
            case .error: return .statusError
            case .success: return .statusSuccess
            }
        }

        var label: String {
            switch self {
            case .idle: return "Idle"
            case .printing: return "Printing"
            case .paused: return "Paused"
            case .error: return "Error"
            case .success: return "Complete"
            }
        }

        var systemImage: String {
            switch self {
            case .idle: return "pause.circle"
            case .printing: return "play.circle.fill"
            case .paused: return "pause.circle.fill"
            case .error: return "exclamationmark.circle.fill"
            case .success: return "checkmark.circle.fill"
            }
        }
    }

    let status: Status
    let showLabel: Bool

    init(_ status: Status, showLabel: Bool = true) {
        self.status = status
        self.showLabel = showLabel
    }

    var body: some View {
        HStack(spacing: BambuSpacing.sm) {
            Image(systemName: status.systemImage)
                .foregroundColor(status.color)

            if showLabel {
                Text(status.label)
                    .font(BambuTextStyle.caption)
                    .foregroundColor(status.color)
            }
        }
    }
}

// MARK: - Loading Spinner
struct LoadingSpinner: View {
    @State private var rotation: Double = 0

    var body: some View {
        Image(systemName: "arrow.3.trianglepath")
            .foregroundColor(.bambuPrimary)
            .rotationEffect(.degrees(rotation))
            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotation)
            .onAppear {
                rotation = 360
            }
    }
}

// MARK: - Progress Ring
struct ProgressRing: View {
    let progress: Double
    let strokeWidth: CGFloat

    init(progress: Double, strokeWidth: CGFloat = 8) {
        self.progress = progress
        self.strokeWidth = strokeWidth
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: strokeWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.bambuPrimary,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)

            Text("\(Int(progress * 100))%")
                .font(BambuTextStyle.caption)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - WiFi Signal Strength Indicator
struct WiFiSignalIndicator: View {
    let signalStrength: Int // 0-3

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 1)
                    .frame(width: 3, height: CGFloat(4 + index * 2))
                    .foregroundColor(index < signalStrength ? .bambuPrimary : .gray.opacity(0.3))
            }
        }
    }
}

// MARK: - View Extensions
extension View {
    func bambuCard() -> some View {
        modifier(BambuCardStyle())
    }

    func bambuPrimaryButton() -> some View {
        buttonStyle(BambuPrimaryButtonStyle())
    }

    func bambuSecondaryButton() -> some View {
        buttonStyle(BambuSecondaryButtonStyle())
    }

    func bambuDestructiveButton() -> some View {
        buttonStyle(BambuDestructiveButtonStyle())
    }
}

// MARK: - Haptic Feedback
struct HapticFeedback {
    static func light() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    static func medium() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }

    static func heavy() {
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
    }

    static func success() {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
    }

    static func error() {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.error)
    }
}

// MARK: - Animation Presets
struct BambuAnimations {
    static let bounce = Animation.spring(duration: 0.6, bounce: 0.4)
    static let smooth = Animation.easeInOut(duration: 0.3)
    static let quick = Animation.easeInOut(duration: 0.15)
    static let slow = Animation.easeInOut(duration: 0.8)
}