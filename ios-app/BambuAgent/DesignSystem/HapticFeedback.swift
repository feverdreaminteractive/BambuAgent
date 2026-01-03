import UIKit

struct HapticFeedback {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    static func light() {
        light.prepare()
        light.impactOccurred()
    }

    static func medium() {
        medium.prepare()
        medium.impactOccurred()
    }

    static func heavy() {
        heavy.prepare()
        heavy.impactOccurred()
    }

    static func selection() {
        selection.prepare()
        selection.selectionChanged()
    }

    static func success() {
        notification.prepare()
        notification.notificationOccurred(.success)
    }

    static func warning() {
        notification.prepare()
        notification.notificationOccurred(.warning)
    }

    static func error() {
        notification.prepare()
        notification.notificationOccurred(.error)
    }
}