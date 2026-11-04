import SwiftUI
import UIKit

/// Colors taken from the app icon. Each adapts to light and dark mode.
enum Palette {
    static let accent = Color(light: 0x6C5CE7, dark: 0xA99BFF)
    static let ink = Color(light: 0x2B2D5C, dark: 0xF4F2FF)
    static let skyTop = Color(light: 0xEAF4FF, dark: 0x14173A)
    static let skyBottom = Color(light: 0xF4ECFF, dark: 0x251D4D)
    static let card = Color(light: 0xFFFFFF, dark: 0x2A2557)
    static let blush = Color(hex: 0xFF9EB5)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// UIKit-drawn chrome (navigation bar titles) doesn't pick up SwiftUI's `fontDesign`,
/// so the rounded design is applied through appearance proxies.
@MainActor
enum AppAppearance {
    static func configure() {
        let titleAttributes: [NSAttributedString.Key: Any] = [.font: roundedFont(.headline, weight: .semibold)]
        let largeTitleAttributes: [NSAttributedString.Key: Any] = [.font: roundedFont(.largeTitle, weight: .bold)]

        let standard = UINavigationBarAppearance()
        standard.configureWithDefaultBackground()
        standard.titleTextAttributes = titleAttributes
        standard.largeTitleTextAttributes = largeTitleAttributes

        // Transparent at the top so the sky backdrop shows through.
        let scrollEdge = UINavigationBarAppearance()
        scrollEdge.configureWithTransparentBackground()
        scrollEdge.titleTextAttributes = titleAttributes
        scrollEdge.largeTitleTextAttributes = largeTitleAttributes

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = standard
        navigationBar.compactAppearance = standard
        navigationBar.scrollEdgeAppearance = scrollEdge
    }

    private static func roundedFont(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let size = UIFont.preferredFont(forTextStyle: style).pointSize
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = font.fontDescriptor.withDesign(.rounded) else { return font }
        return UIFont(descriptor: descriptor, size: size)
    }
}
