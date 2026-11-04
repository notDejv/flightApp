import SwiftUI

enum MoreItem: String, CaseIterable, Identifiable, Hashable {
    case settings, help, about, contact

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .settings: "gearshape"
        case .help: "questionmark.circle"
        case .about: "info.circle"
        case .contact: "envelope"
        }
    }
}

struct MoreView: View {
    var body: some View {
        NavigationStack {
            List(MoreItem.allCases) { item in
                NavigationLink(value: item) {
                    Label(item.title, systemImage: item.icon)
                }
            }
            .listStyle(.insetGrouped)
            .skyBackground()
            .navigationTitle("More")
            .navigationDestination(for: MoreItem.self) { item in
                PlaceholderView(item: item)
            }
        }
    }
}

struct PlaceholderView: View {
    let item: MoreItem

    var body: some View {
        MascotEmptyState(mood: .sleepy, title: item.title, message: "Nothing here yet. Check back soon!")
            .background { SkyBackground() }
            .navigationTitle(item.title)
    }
}
