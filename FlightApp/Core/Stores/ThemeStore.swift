import Observation
import SwiftUI
import UIKit

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Persists the theme choice (system by default) and applies it to every window.
///
/// The override is set on `UIWindow` rather than via `preferredColorScheme`, so
/// navigation bars, tab bars and presented sheets follow it, and switching back
/// to `.system` takes effect immediately.
@Observable
@MainActor
final class ThemeStore {
    var theme: AppTheme {
        didSet {
            defaults.set(theme.rawValue, forKey: key)
            apply()
        }
    }

    private let defaults: UserDefaults
    private let key = "theme"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        theme = defaults.string(forKey: key).flatMap(AppTheme.init(rawValue:)) ?? .system
    }

    func apply() {
        let style = theme.interfaceStyle
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
