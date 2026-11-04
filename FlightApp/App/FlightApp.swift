import SwiftData
import SwiftUI

@main
struct FlightApp: App {
    @State private var dependencies = AppDependencies.live()

    init() {
        AppAppearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(dependencies)
                .environment(dependencies.session)
                .environment(dependencies.theme)
                .environment(dependencies.favorites)
                .environment(dependencies.liveActivities)
        }
        .modelContainer(dependencies.modelContainer)
    }
}
