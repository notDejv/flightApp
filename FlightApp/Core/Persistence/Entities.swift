import Foundation
import SwiftData

/// Persisted recent search, owned by one user. The criteria are stored as an encoded
/// payload because the app only ever reads them back whole, ordered by `createdAt`.
@Model
final class RecentSearchEntity {
    var ownerID: String = ""
    var key: String
    var createdAt: Date
    var payload: Data

    init(ownerID: String, key: String, createdAt: Date, payload: Data) {
        self.ownerID = ownerID
        self.key = key
        self.createdAt = createdAt
        self.payload = payload
    }
}

/// Persisted favorite, owned by one user: a snapshot of the flight at the time it was saved.
@Model
final class FavoriteFlightEntity {
    var ownerID: String = ""
    var flightID: String
    var savedAt: Date
    var payload: Data

    init(ownerID: String, flightID: String, savedAt: Date, payload: Data) {
        self.ownerID = ownerID
        self.flightID = flightID
        self.savedAt = savedAt
        self.payload = payload
    }
}

enum PersistenceStack {
    static let schema = Schema([RecentSearchEntity.self, FavoriteFlightEntity.self])

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        if !inMemory {
            // The default store lives here; creating it up front avoids Core Data's
            // noisy "Failed to stat path" logging on first launch.
            try FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        }
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
